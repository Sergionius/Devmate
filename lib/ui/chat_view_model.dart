import 'package:flutter/foundation.dart';

import '../data/chat_history_repository.dart';
import '../data/chat_tools.dart';
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
    this.onSessionDetached,
    this.historyRepository,
    this.chatId,
    ChatSession Function(LlmSettings settings, String systemPrompt)?
    sessionFactory,
  }) : _customSessionFactory = sessionFactory != null,
       _sessionFactory =
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

  final void Function(ChatSession session)? onSessionDetached;
  final ChatHistoryRepository? historyRepository;
  final String? chatId;
  List<LlmChatMessage> _savedMessages = const [];
  Object? persistenceError;

  final bool _customSessionFactory;
  final ChatSession Function(LlmSettings settings, String systemPrompt)
  _sessionFactory;

  ChatSession? _session;
  ChatSettingsPhase _settingsPhase = ChatSettingsPhase.loading;
  LlmSettings? _settings;
  String _exaKey = '';
  String _braveKey = '';
  String _tavilyKey = '';
  String _searchProvider = 'exa';
  Object? _settingsError;
  bool historyLoadFailed = false;
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
      _exaKey = await settingsRepository.loadExaKey();
      _braveKey = await settingsRepository.loadBraveKey();
      _tavilyKey = await settingsRepository.loadTavilyKey();
      _searchProvider = await settingsRepository.loadSearchProvider();
      historyLoadFailed = true;
      if (historyRepository != null && chatId != null) {
        if (await historyRepository!.get(chatId!) == null) {
          throw StateError('Conversation not found');
        }
        _savedMessages = await historyRepository!.loadMessages(chatId!);
      }
      historyLoadFailed = false;
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
    _attachSession(
      historyRepository != null && chatId != null
          ? OpenAiCompatibleProvider(
              settings: settings,
              systemPrompt: systemPrompt,
              initialHistory: _savedMessages,
              tools: ChatTools(
                catalog: catalog,
                exaKey: _exaKey,
                braveKey: _braveKey,
                tavilyKey: _tavilyKey,
                searchProvider: _searchProvider,
                allowedEditQuestionId: editQuestionId,
              ),
            )
          : !_customSessionFactory
          ? OpenAiCompatibleProvider(
              settings: settings,
              systemPrompt: systemPrompt,
              tools: ChatTools(
                catalog: catalog,
                exaKey: _exaKey,
                braveKey: _braveKey,
                tavilyKey: _tavilyKey,
                searchProvider: _searchProvider,
                allowedEditQuestionId: editQuestionId,
              ),
            )
          : _sessionFactory(settings, systemPrompt),
    );
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
    onSessionDetached?.call(session);
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

  String? get retryPrompt {
    final history = messages;
    if (_streaming ||
        history.length < 2 ||
        history.last.role != LlmRole.assistant ||
        !history.last.failed ||
        history[history.length - 2].role != LlmRole.user) {
      return null;
    }
    return history[history.length - 2].text;
  }

  Future<void> retry() async {
    final prompt = retryPrompt;
    if (prompt != null) await send(prompt, retry: true);
  }

  Future<void> send(String text, {bool retry = false}) async {
    text = text.trim();
    final session = _session;
    if (text.isEmpty || _streaming || session == null) return;
    _streaming = true;
    _notify();
    try {
      await for (final _ in session.sendMessageStream(text, retry: retry)) {}
    } catch (error) {
      debugPrint('ChatViewModel: response stream failed: $error');
    } finally {
      _streaming = false;
      _parseReplyActions();
      _notify();
    }

    if (historyRepository != null && chatId != null) {
      if (_disposed &&
          session.history.isNotEmpty &&
          session.history.last.role == LlmRole.assistant &&
          session.history.last.text.isEmpty &&
          !session.history.last.failed) {
        session.history.last
          ..failed = true
          ..errorKind = LlmErrorKind.emptyReply;
      }
      try {
        await historyRepository!.saveMessages(chatId!, session.history);
        persistenceError = null;
        _savedMessages = session.history;
      } catch (error) {
        persistenceError = error;
        debugPrint('ChatViewModel: failed to save history: $error');
        _notify();
      }
    }

    if (_reloadPending) {
      _reloadPending = false;
      await reloadSettings();
    }
  }

  void _parseReplyActions() {
    final catalog = this.catalog;
    final session = _session;
    if (catalog == null ||
        session == null ||
        session.history.isEmpty ||
        session.history.last.failed) {
      return;
    }
    final reply = session.history.last.text;
    final toolSession = session is OpenAiCompatibleProvider ? session : null;
    if (editQuestionId != null) {
      if (toolSession?.proposedAnswerUpdate case final update?) {
        _answerUpdate = update;
        _draft = null;
        return;
      }
      final update = parseAnswerUpdate(reply);
      if (update != null) {
        _answerUpdate = update;
        _draft = null;
      }
      return;
    }
    final draft = toolSession?.proposedDraft ?? parseTopicDraft(reply);
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
