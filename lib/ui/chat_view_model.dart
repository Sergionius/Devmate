import 'package:flutter/foundation.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../data/topic_draft.dart';

/// Исход сохранения из чата; текст снекбара локализуется в UI.
enum ChatSaveOutcome { contentAdded, answerReplaced, saveFailed }

/// Состояние загрузки LLM-настроек чатом.
enum ChatSettingsPhase { loading, ready, error }

/// Состояние и логика одного чата: загрузка настроек, стрим ответов,
/// карточки черновика темы и правки ответа. ChatScreen только рендерит
/// и переводит исходы в локализованные снекбары.
class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required this.settingsRepository,
    this.systemPrompt = '',
    this.catalog,
    this.appendToTopic,
    this.editQuestionId,
    ChatSession Function(LlmSettings settings, String systemPrompt)?
    sessionFactory,
  }) : _sessionFactory =
           sessionFactory ??
           ((settings, prompt) =>
               OpenAiCompatibleProvider(settings: settings, systemPrompt: prompt));

  final LlmSettingsRepository settingsRepository;
  final String systemPrompt;

  /// Задан только в чатах работы с темами: после ответа модели логика ищет
  /// JSON-черновик и показывает карточку с действием.
  final TopicCatalog? catalog;

  /// Если задан — черновик воспринимается как вопросы для этой темы
  /// (без поля title), а кнопка добавляет их в неё.
  final String? appendToTopic;

  /// Если задан — ответы модели в этом чате могут заменять ответ этого
  /// вопроса (JSON action=update_answer).
  final String? editQuestionId;

  final ChatSession Function(LlmSettings settings, String systemPrompt)
  _sessionFactory;

  ChatSession? _session;
  ChatSettingsPhase _settingsPhase = ChatSettingsPhase.loading;
  LlmSettings? _settings;
  Object? _settingsError;
  bool _streaming = false;
  bool _draftSaving = false;
  TopicDraft? _draft;
  AnswerUpdate? _answerUpdate;
  int _messageCount = 0;
  bool _reloadPending = false;
  bool _disposed = false;

  ChatSession? get session => _session;
  ChatSettingsPhase get settingsPhase => _settingsPhase;
  Object? get settingsError => _settingsError;
  LlmSettings? get settings => _settings;
  bool get streaming => _streaming;
  bool get draftSaving => _draftSaving;
  TopicDraft? get draft => _draft;
  AnswerUpdate? get answerUpdate => _answerUpdate;

  /// Сообщения диалога; единственный источник — сессия, копий нет.
  List<LlmChatMessage> get messages =>
      _session?.history ?? const <LlmChatMessage>[];

  /// Название темы в append-режиме; null — создание новой темы.
  String? get appendTopicTitle =>
      appendToTopic == null
          ? null
          : (catalog?.topicById(appendToTopic!)?.title ?? appendToTopic);

  Future<void> loadSettings() async {
    _settingsPhase = ChatSettingsPhase.loading;
    _notify();
    try {
      _settings = await settingsRepository.load();
      _settingsError = null;
      _settingsPhase = ChatSettingsPhase.ready;
    } catch (error) {
      _settingsError = error;
      _settingsPhase = ChatSettingsPhase.error;
      debugPrint('ChatViewModel: загрузка настроек не удалась: $error');
    } finally {
      _notify();
    }
  }

  /// Создаёт сессию, когда настройки готовы и сконфигурированы.
  /// Идемпотентно; без notify — безопасно вызывать из build.
  void ensureSession() {
    final settings = _settings;
    if (_session != null || settings == null || !settings.isConfigured) {
      return;
    }
    _attachSession(_sessionFactory(settings, systemPrompt));
  }

  /// Перечитывает настройки: старая сессия закрывается, диалог сбрасывается.
  /// Во время стрима откладывается до его завершения — сессию нельзя рвать
  /// на полуслове, но и молча терять новые настройки нельзя.
  Future<void> reloadSettings() async {
    if (_streaming) {
      _reloadPending = true;
      return;
    }
    _detachSession();
    _draft = null;
    _answerUpdate = null;
    await loadSettings();
  }

  void _attachSession(ChatSession session) {
    _session = session;
    _messageCount = 0;
    session.addListener(_onSessionChanged);
  }

  void _detachSession() {
    final session = _session;
    if (session == null) return;
    session.removeListener(_onSessionChanged);
    session.dispose();
    _session = null;
    _messageCount = 0;
  }

  /// Сессия уведомляет на каждый чанк; список сообщений перестраивается
  /// только когда меняется их количество. Текст последнего ответа экран
  /// слушает напрямую у сессии (гранулярный ребилд пузыря).
  void _onSessionChanged() {
    final count = _session?.history.length ?? 0;
    if (count == _messageCount) return;
    _messageCount = count;
    _notify();
  }

  Future<void> send(String text) async {
    text = text.trim();
    final session = _session;
    if (text.isEmpty || _streaming || session == null) return;
    _streaming = true;
    _notify();
    try {
      // Текст чанков провайдер уже положил в историю; экран слушает
      // сессию напрямую, поэтому здесь цикл только ждёт завершения.
      await for (final _ in session.sendMessageStream(text)) {}
    } catch (error) {
      // Провайдер нормализует ошибки в errorKind; сюда попадают только
      // сбои самого стрима до нормализации.
      debugPrint('ChatViewModel: сбой потока ответа: $error');
    } finally {
      _streaming = false;
      _parseReplyActions();
      _notify();
    }
    // Настройки, изменённые во время стрима, подхватываем сразу после него.
    if (_reloadPending) {
      _reloadPending = false;
      await reloadSettings();
    }
  }

  /// После ответа модели ищет в тексте JSON-команды: черновик темы
  /// или правку ответа. Только в чатах работы с темами.
  void _parseReplyActions() {
    final catalog = this.catalog;
    final session = _session;
    if (catalog == null || session == null) return;
    final reply = session.history.last.text;
    if (editQuestionId != null) {
      final update = parseAnswerUpdate(reply);
      if (update != null) {
        _answerUpdate = update;
        _draft = null;
      }
      return;
    }
    final draft = parseTopicDraft(reply);
    if (draft == null) {
      // Уточняющий ответ: карточка от прошлого хода больше не актуальна.
      _draft = null;
    } else if (appendToTopic != null || draft.title != null) {
      _draft = draft;
    }
  }

  /// Добавляет черновик: новую тему или вопросы в существующую.
  /// null — применять нечего или сохранение уже идёт.
  Future<ChatSaveOutcome?> applyDraft() async {
    final draft = _draft;
    if (draft == null || _draftSaving) return null;
    _draftSaving = true;
    _notify();
    try {
      if (appendToTopic != null) {
        await catalog!.addQuestionsToTopic(appendToTopic!, draft.questions);
      } else {
        await catalog!.addUserTopic(
          draft.title!,
          draft.description ?? '',
          draft.questions,
        );
      }
      _draft = null;
      return ChatSaveOutcome.contentAdded;
    } catch (error) {
      debugPrint('ChatViewModel: сохранение черновика не удалось: $error');
      return ChatSaveOutcome.saveFailed;
    } finally {
      _draftSaving = false;
      _notify();
    }
  }

  /// Заменяет эталонный ответ вопроса на предложенный моделью.
  /// null — применять нечего или сохранение уже идёт.
  Future<ChatSaveOutcome?> replaceAnswer() async {
    final update = _answerUpdate;
    if (update == null || editQuestionId == null || _draftSaving) return null;
    _draftSaving = true;
    _notify();
    try {
      await catalog!.updateQuestion(
        editQuestionId!,
        update.prompt,
        update.answer,
      );
      _answerUpdate = null;
      return ChatSaveOutcome.answerReplaced;
    } catch (error) {
      debugPrint('ChatViewModel: замена ответа не удалась: $error');
      return ChatSaveOutcome.saveFailed;
    } finally {
      _draftSaving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    // Сессия в dispose() отменяет активный стрим (контракт ChatSession):
    // HTTP-соединение рвётся, потребитель получает done — ничего
    // не висит и не течёт.
    _detachSession();
    _disposed = true;
    super.dispose();
  }
}
