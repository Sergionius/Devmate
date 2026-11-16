import 'package:flutter/foundation.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../data/topic_draft.dart';

enum ChatSaveOutcome { contentAdded, answerReplaced, saveFailed }

enum ChatSettingsPhase { loading, ready, error }

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
           ((settings, prompt) => OpenAiCompatibleProvider(
             settings: settings,
             systemPrompt: prompt,
           ));

  final LlmSettingsRepository settingsRepository;
  final String systemPrompt;

  final TopicCatalog? catalog;

  final String? appendToTopic;

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

  List<LlmChatMessage> get messages =>
      _session?.history ?? const <LlmChatMessage>[];

  String? get appendTopicTitle => appendToTopic == null
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
      debugPrint('ChatViewModel: failed to load settings: $error');
    } finally {
      _notify();
    }
  }

  void ensureSession() {
    final settings = _settings;
    if (_session != null || settings == null || !settings.isConfigured) {
      return;
    }
    _attachSession(_sessionFactory(settings, systemPrompt));
  }

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
      await for (final _ in session.sendMessageStream(text)) {}
    } catch (error) {
      debugPrint('ChatViewModel: response stream failed: $error');
    } finally {
      _streaming = false;
      _parseReplyActions();
      _notify();
    }

    if (_reloadPending) {
      _reloadPending = false;
      await reloadSettings();
    }
  }

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
      _draft = null;
    } else if (appendToTopic != null || draft.title != null) {
      _draft = draft;
    }
  }

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
      debugPrint('ChatViewModel: failed to save draft: $error');
      return ChatSaveOutcome.saveFailed;
    } finally {
      _draftSaving = false;
      _notify();
    }
  }

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
      debugPrint('ChatViewModel: failed to replace answer: $error');
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
    _detachSession();
    _disposed = true;
    super.dispose();
  }
}
