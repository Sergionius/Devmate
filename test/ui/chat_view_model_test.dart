import 'dart:async';

import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/ui/chat_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

LlmSettingsRepository _settingsRepo() =>
    LlmSettingsRepository(storage: MemorySecureStorage());

class _MemoryTopicsRepository implements UserTopicsRepository {
  final savedTopics = <List<Map<String, dynamic>>>[];
  final savedExtra = <Map<String, List<Map<String, dynamic>>>>[];
  final savedOverrides = <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> load() async => const [];

  @override
  Future<Map<String, List<Map<String, dynamic>>>> loadExtra() async => const {};

  @override
  Future<Map<String, dynamic>> loadOverrides() async => const {};

  @override
  Future<void> save(List<Map<String, dynamic>> topics) async =>
      savedTopics.add(topics);

  @override
  Future<void> saveExtra(Map<String, List<Map<String, dynamic>>> extra) async =>
      savedExtra.add(extra);

  @override
  Future<void> saveOverrides(Map<String, dynamic> overrides) async =>
      savedOverrides.add(overrides);
}

class _FakeSession extends ChangeNotifier implements ChatSession {
  _FakeSession(this._replies);

  final List<Object> _replies;
  final List<LlmChatMessage> _history = [];
  var _replyIndex = 0;
  StreamController<String>? _pending;

  @override
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  @override
  Stream<String> sendMessageStream(String prompt) {
    _history
      ..add(LlmChatMessage(LlmRole.user, prompt))
      ..add(LlmChatMessage(LlmRole.assistant, ''));
    notifyListeners();
    final reply = _replyIndex < _replies.length ? _replies[_replyIndex++] : '';
    if (reply is Stream<String>) {
      final controller = StreamController<String>();
      _pending = controller;
      reply.listen(
        controller.add,
        onError: controller.addError,
        onDone: () {
          _pending = null;
          unawaited(controller.close());
        },
        cancelOnError: true,
      );
      return controller.stream;
    }
    return _streamReply(reply);
  }

  Stream<String> _streamReply(Object reply) async* {
    if (reply is Exception) throw reply;
    for (final chunk in (reply as String).split('|')) {
      _history.last.text += chunk;
      notifyListeners();
      yield chunk;
    }
  }

  @override
  void dispose() {
    final pending = _pending;
    _pending = null;
    unawaited(pending?.close());
    super.dispose();
  }
}

ChatViewModel _viewModel({
  required LlmSettingsRepository settingsRepository,
  TopicCatalog? catalog,
  String? appendToTopic,
  String? editQuestionId,
  required _FakeSession session,
}) {
  final viewModel = ChatViewModel(
    settingsRepository: settingsRepository,
    catalog: catalog,
    appendToTopic: appendToTopic,
    editQuestionId: editQuestionId,
    sessionFactory: (_, _) => session,
  );
  return viewModel;
}

Future<LlmSettingsRepository> _configuredRepo() async {
  final repo = _settingsRepo();
  await repo.save(
    const LlmSettings(baseUrl: 'https://api.test/v1', model: 'm', apiKey: 'k'),
  );
  return repo;
}

const _draftJson =
    '{"title":"Docker","description":"Basics","questions":'
    '[{"prompt":"What is an image?","answer":"A filesystem template"}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('send consumes the stream to the end and fills the history', () async {
    final repo = await _configuredRepo();
    final session = _FakeSession(['Hello|, world']);
    final viewModel = _viewModel(settingsRepository: repo, session: session);

    await viewModel.loadSettings();
    expect(viewModel.settingsPhase, ChatSettingsPhase.ready);
    viewModel.ensureSession();
    expect(viewModel.session, same(session));

    await viewModel.send('  question  ');
    expect(viewModel.messages, hasLength(2));
    expect(viewModel.messages.first.text, 'question');
    expect(viewModel.messages.last.text, 'Hello, world');
    expect(viewModel.streaming, isFalse);
  });

  test('send ignores reentrant calls while a stream is in flight', () async {
    final repo = await _configuredRepo();
    final controller = StreamController<String>();
    final session = _FakeSession([controller.stream]);
    final viewModel = _viewModel(settingsRepository: repo, session: session);
    await viewModel.loadSettings();
    viewModel.ensureSession();

    final sending = viewModel.send('first');
    expect(viewModel.streaming, isTrue);

    await viewModel.send('second');
    expect(session.history, hasLength(2));

    await controller.close();
    await sending;
    expect(viewModel.streaming, isFalse);
  });

  test(
    'a stream failure does not crash send and completes streaming',
    () async {
      final repo = await _configuredRepo();
      final session = _FakeSession([Exception('network')]);
      final viewModel = _viewModel(settingsRepository: repo, session: session);
      await viewModel.loadSettings();
      viewModel.ensureSession();

      await viewModel.send('question');
      expect(viewModel.messages, hasLength(2));
      expect(viewModel.streaming, isFalse);
    },
  );

  test('a topic draft is parsed and added as a new topic', () async {
    final repo = await _configuredRepo();
    final topics = _MemoryTopicsRepository();
    final catalog = TopicCatalog(userTopicsRepository: topics);
    final session = _FakeSession(['Here is a topic: $_draftJson']);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: catalog,
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();

    await viewModel.send('make a topic');
    expect(viewModel.draft?.title, 'Docker');
    expect(viewModel.draft?.questions, hasLength(1));

    final outcome = await viewModel.applyDraft();
    expect(outcome, ChatSaveOutcome.contentAdded);
    expect(viewModel.draft, isNull);
    expect(topics.savedTopics, hasLength(1));
  });

  test('a clarifying reply instead of a draft drops the stale card', () async {
    final repo = await _configuredRepo();
    final catalog = TopicCatalog();
    final session = _FakeSession([_draftJson, 'Clarify: do you mean images?']);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: catalog,
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();

    await viewModel.send('make a topic');
    expect(viewModel.draft, isNotNull);

    await viewModel.send('clarify');
    expect(viewModel.draft, isNull);
  });

  test('append mode adds questions to the existing topic', () async {
    final repo = await _configuredRepo();
    final topics = _MemoryTopicsRepository();
    final catalog = TopicCatalog(userTopicsRepository: topics);
    final topicId = catalog.topics.first.id;
    const questionsJson =
        '{"questions":[{"prompt":"What is a pod?","answer":"A group of containers"}]}';
    final session = _FakeSession([questionsJson]);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: catalog,
      appendToTopic: topicId,
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();

    await viewModel.send('add a question');
    expect(viewModel.draft?.questions, hasLength(1));
    expect(viewModel.appendTopicTitle, catalog.topics.first.title);

    final outcome = await viewModel.applyDraft();
    expect(outcome, ChatSaveOutcome.contentAdded);
    expect(topics.savedExtra, hasLength(1));
  });

  test('update_answer shows the edit and replaceAnswer applies it', () async {
    final repo = await _configuredRepo();
    final topics = _MemoryTopicsRepository();
    final catalog = TopicCatalog(userTopicsRepository: topics);
    final question = catalog.topics.first.questions.first;
    final reply =
        '{"action":"update_answer","prompt":"Refined question",'
        '"answer":"A new answer"}';
    final session = _FakeSession([reply]);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: catalog,
      editQuestionId: question.id,
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();

    await viewModel.send('rewrite the answer');
    expect(viewModel.answerUpdate?.prompt, 'Refined question');
    expect(viewModel.draft, isNull);

    final outcome = await viewModel.replaceAnswer();
    expect(outcome, ChatSaveOutcome.answerReplaced);
    expect(viewModel.answerUpdate, isNull);
    expect(topics.savedOverrides, hasLength(1));
    final updated = catalog
        .topicById(catalog.topics.first.id)!
        .questions
        .firstWhere((q) => q.id == question.id);
    expect(updated.answer, 'A new answer');
  });

  test('applyDraft without a draft and replaceAnswer without an update return null', () async {
    final repo = await _configuredRepo();
    final session = _FakeSession(['Just text']);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: TopicCatalog(),
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();
    await viewModel.send('hello');

    expect(await viewModel.applyDraft(), isNull);
    expect(await viewModel.replaceAnswer(), isNull);
  });

  test('unconfigured settings: no session is created', () async {
    final repo = _settingsRepo();
    final session = _FakeSession(['reply']);
    final viewModel = _viewModel(settingsRepository: repo, session: session);
    await viewModel.loadSettings();

    expect(viewModel.settingsPhase, ChatSettingsPhase.ready);
    expect(viewModel.settings?.isConfigured, isFalse);
    viewModel.ensureSession();
    expect(viewModel.session, isNull);
    await viewModel.send('question');
    expect(session.history, isEmpty);
  });

  test(
    'reloadSettings resets the conversation and creates a new session',
    () async {
      final repo = await _configuredRepo();
      var call = 0;
      final first = _FakeSession(['reply 1']);
      final second = _FakeSession(['reply 2']);
      final viewModel = ChatViewModel(
        settingsRepository: repo,
        sessionFactory: (_, _) => ++call == 1 ? first : second,
      );
      await viewModel.loadSettings();
      viewModel.ensureSession();
      await viewModel.send('question');
      expect(viewModel.messages, hasLength(2));

      await repo.save(
        const LlmSettings(
          baseUrl: 'https://api.test/v1',
          model: 'new-model',
          apiKey: 'k2',
        ),
      );
      await viewModel.reloadSettings();

      expect(viewModel.messages, isEmpty);
      viewModel.ensureSession();
      expect(viewModel.session, same(second));
      expect(viewModel.settings?.model, 'new-model');
    },
  );

  test('reloadSettings during a stream is deferred until it ends', () async {
    final repo = await _configuredRepo();
    final controller = StreamController<String>();
    final session = _FakeSession([controller.stream]);
    final viewModel = _viewModel(settingsRepository: repo, session: session);
    await viewModel.loadSettings();
    viewModel.ensureSession();

    final sending = viewModel.send('question');
    await viewModel.reloadSettings();

    expect(viewModel.streaming, isTrue);
    expect(viewModel.messages, hasLength(2));

    await controller.close();
    await sending;

    expect(viewModel.messages, isEmpty);
    expect(viewModel.session, isNull);
    expect(viewModel.streaming, isFalse);
  });

  test(
    'dispose during a stream cancels the stream and completes send',
    () async {
      final repo = await _configuredRepo();
      final controller = StreamController<String>();
      final session = _FakeSession([controller.stream]);
      final viewModel = _viewModel(settingsRepository: repo, session: session);
      await viewModel.loadSettings();
      viewModel.ensureSession();

      final sending = viewModel.send('question');
      viewModel.dispose();

      await sending.timeout(const Duration(seconds: 2));
      expect(viewModel.streaming, isFalse);
      await controller.close();
    },
  );

  test('a settings read failure yields the error phase', () async {
    final repo = LlmSettingsRepository(storage: _ThrowingStorage());
    final session = _FakeSession(['reply']);
    final viewModel = _viewModel(settingsRepository: repo, session: session);

    await viewModel.loadSettings();
    expect(viewModel.settingsPhase, ChatSettingsPhase.error);
    expect(viewModel.settingsError, isA<Exception>());
    viewModel.ensureSession();
    expect(viewModel.session, isNull);
  });
}

class _ThrowingStorage extends MemorySecureStorage {
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => throw Exception('storage locked');
}
