import 'dart:async';

import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/ui/chat_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

/// Подменяет [LlmSettingsRepository]'s storage — ключи пишутся в память.
LlmSettingsRepository _settingsRepo() =>
    LlmSettingsRepository(storage: MemorySecureStorage());

/// In-memory [UserTopicsRepository]: фиксирует все сохранения.
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
  Future<void> saveExtra(
    Map<String, List<Map<String, dynamic>>> extra,
  ) async => savedExtra.add(extra);

  @override
  Future<void> saveOverrides(Map<String, dynamic> overrides) async =>
      savedOverrides.add(overrides);
}

/// Фейк сессии: история как у провайдера, ответы — по очереди из списка.
/// Элемент списка: String (чанки через |), Exception (сбой стрима)
/// или готовый `Stream<String>` (например, незавершаемый).
class _FakeSession extends ChangeNotifier implements ChatSession {
  _FakeSession(this._replies);

  final List<Object> _replies;
  final List<LlmChatMessage> _history = [];
  var _replyIndex = 0;

  @override
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  @override
  Stream<String> sendMessageStream(String prompt) {
    _history
      ..add(LlmChatMessage(LlmRole.user, prompt))
      ..add(LlmChatMessage(LlmRole.assistant, ''));
    notifyListeners();
    final reply = _replyIndex < _replies.length
        ? _replies[_replyIndex++]
        : '';
    if (reply is Stream<String>) return reply;
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
    '{"title":"Docker","description":"Основы","questions":'
    '[{"prompt":"Что такое image?","answer":"Шаблон файловой системы"}]}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('send проходит стрим до конца и наполняет историю', () async {
    final repo = await _configuredRepo();
    final session = _FakeSession(['Привет|, мир']);
    final viewModel = _viewModel(settingsRepository: repo, session: session);

    await viewModel.loadSettings();
    expect(viewModel.settingsPhase, ChatSettingsPhase.ready);
    viewModel.ensureSession();
    expect(viewModel.session, same(session));

    await viewModel.send('  вопрос  ');
    expect(viewModel.messages, hasLength(2));
    expect(viewModel.messages.first.text, 'вопрос');
    expect(viewModel.messages.last.text, 'Привет, мир');
    expect(viewModel.streaming, isFalse);
  });

  test('send при незавершённом стриме игнорирует повторные вызовы', () async {
    final repo = await _configuredRepo();
    final controller = StreamController<String>();
    final session = _FakeSession([controller.stream]);
    final viewModel = _viewModel(settingsRepository: repo, session: session);
    await viewModel.loadSettings();
    viewModel.ensureSession();

    final sending = viewModel.send('первый');
    expect(viewModel.streaming, isTrue);

    await viewModel.send('второй');
    expect(session.history, hasLength(2)); // второй не добавил сообщений

    await controller.close();
    await sending;
    expect(viewModel.streaming, isFalse);
  });

  test('сбой стрима не роняет send и завершает streaming', () async {
    final repo = await _configuredRepo();
    final session = _FakeSession([Exception('network')]);
    final viewModel = _viewModel(settingsRepository: repo, session: session);
    await viewModel.loadSettings();
    viewModel.ensureSession();

    await viewModel.send('вопрос');
    expect(viewModel.messages, hasLength(2));
    expect(viewModel.streaming, isFalse);
  });

  test('черновик темы парсится и добавляется новой темой', () async {
    final repo = await _configuredRepo();
    final topics = _MemoryTopicsRepository();
    final catalog = TopicCatalog(userTopicsRepository: topics);
    final session = _FakeSession(['Вот тема: $_draftJson']);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: catalog,
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();

    await viewModel.send('сделай тему');
    expect(viewModel.draft?.title, 'Docker');
    expect(viewModel.draft?.questions, hasLength(1));

    final outcome = await viewModel.applyDraft();
    expect(outcome, ChatSaveOutcome.contentAdded);
    expect(viewModel.draft, isNull);
    expect(topics.savedTopics, hasLength(1));
  });

  test('уточнение вместо черновика сбрасывает устаревшую карточку', () async {
    final repo = await _configuredRepo();
    final catalog = TopicCatalog();
    final session = _FakeSession([_draftJson, 'Уточню: вы про образы?']);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: catalog,
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();

    await viewModel.send('сделай тему');
    expect(viewModel.draft, isNotNull);

    await viewModel.send('уточнение');
    expect(viewModel.draft, isNull);
  });

  test('append-режим добавляет вопросы в существующую тему', () async {
    final repo = await _configuredRepo();
    final topics = _MemoryTopicsRepository();
    final catalog = TopicCatalog(userTopicsRepository: topics);
    final topicId = catalog.topics.first.id;
    const questionsJson =
        '{"questions":[{"prompt":"Что такое pod?","answer":"Группа контейнеров"}]}';
    final session = _FakeSession([questionsJson]);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: catalog,
      appendToTopic: topicId,
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();

    await viewModel.send('добавь вопрос');
    expect(viewModel.draft?.questions, hasLength(1));
    expect(viewModel.appendTopicTitle, catalog.topics.first.title);

    final outcome = await viewModel.applyDraft();
    expect(outcome, ChatSaveOutcome.contentAdded);
    expect(topics.savedExtra, hasLength(1));
  });

  test('update_answer показывает правку и replaceAnswer применяет её',
        () async {
    final repo = await _configuredRepo();
    final topics = _MemoryTopicsRepository();
    final catalog = TopicCatalog(userTopicsRepository: topics);
    final question = catalog.topics.first.questions.first;
    final reply =
        '{"action":"update_answer","prompt":"Уточнённый вопрос",'
        '"answer":"Новый ответ"}';
    final session = _FakeSession([reply]);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: catalog,
      editQuestionId: question.id,
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();

    await viewModel.send('перепиши ответ');
    expect(viewModel.answerUpdate?.prompt, 'Уточнённый вопрос');
    expect(viewModel.draft, isNull);

    final outcome = await viewModel.replaceAnswer();
    expect(outcome, ChatSaveOutcome.answerReplaced);
    expect(viewModel.answerUpdate, isNull);
    expect(topics.savedOverrides, hasLength(1));
    final updated = catalog
        .topicById(catalog.topics.first.id)!
        .questions
        .firstWhere((q) => q.id == question.id);
    expect(updated.answer, 'Новый ответ');
  });

  test('applyDraft без черновика и replaceAnswer без правки — null', () async {
    final repo = await _configuredRepo();
    final session = _FakeSession(['Просто текст']);
    final viewModel = _viewModel(
      settingsRepository: repo,
      catalog: TopicCatalog(),
      session: session,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();
    await viewModel.send('привет');

    expect(await viewModel.applyDraft(), isNull);
    expect(await viewModel.replaceAnswer(), isNull);
  });

  test('не сконфигурированные настройки: сессия не создаётся', () async {
    final repo = _settingsRepo(); // пустое хранилище
    final session = _FakeSession(['ответ']);
    final viewModel = _viewModel(settingsRepository: repo, session: session);
    await viewModel.loadSettings();

    expect(viewModel.settingsPhase, ChatSettingsPhase.ready);
    expect(viewModel.settings?.isConfigured, isFalse);
    viewModel.ensureSession();
    expect(viewModel.session, isNull);
    await viewModel.send('вопрос');
    expect(session.history, isEmpty);
  });

  test('reloadSettings сбрасывает диалог и создаёт новую сессию', () async {
    final repo = await _configuredRepo();
    var call = 0;
    final first = _FakeSession(['ответ 1']);
    final second = _FakeSession(['ответ 2']);
    final viewModel = ChatViewModel(
      settingsRepository: repo,
      sessionFactory: (_, _) => ++call == 1 ? first : second,
    );
    await viewModel.loadSettings();
    viewModel.ensureSession();
    await viewModel.send('вопрос');
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
    viewModel.ensureSession(); // как build экрана после notify
    expect(viewModel.session, same(second));
    expect(viewModel.settings?.model, 'new-model');
  });

  test('reloadSettings во время стрима откладывается до его конца', () async {
    final repo = await _configuredRepo();
    final controller = StreamController<String>();
    final session = _FakeSession([controller.stream]);
    final viewModel = _viewModel(settingsRepository: repo, session: session);
    await viewModel.loadSettings();
    viewModel.ensureSession();

    final sending = viewModel.send('вопрос');
    await viewModel.reloadSettings();
    // Стрим ещё идёт: сессия на месте, диалог не тронут.
    expect(viewModel.streaming, isTrue);
    expect(viewModel.messages, hasLength(2));

    await controller.close();
    await sending;
    // Отложенная перезагрузка выполнилась: сессия закрыта, диалог сброшен.
    expect(viewModel.messages, isEmpty);
    expect(viewModel.session, isNull);
    expect(viewModel.streaming, isFalse);
  });

  test('dispose во время стрима не пишет в закрытый нотифаер', () async {
    final repo = await _configuredRepo();
    final controller = StreamController<String>();
    final session = _FakeSession([controller.stream]);
    final viewModel = _viewModel(settingsRepository: repo, session: session);
    await viewModel.loadSettings();
    viewModel.ensureSession();

    final sending = viewModel.send('вопрос');
    viewModel.dispose();

    await controller.close();
    await sending; // не должно бросить: notify после dispose запрещён
    expect(viewModel.streaming, isFalse);
  });

  test('сбой чтения настроек даёт error-фазу', () async {
    final repo = LlmSettingsRepository(storage: _ThrowingStorage());
    final session = _FakeSession(['ответ']);
    final viewModel = _viewModel(settingsRepository: repo, session: session);

    await viewModel.loadSettings();
    expect(viewModel.settingsPhase, ChatSettingsPhase.error);
    expect(viewModel.settingsError, isA<Exception>());
    viewModel.ensureSession();
    expect(viewModel.session, isNull);
  });
}

/// Хранилище, падающее при любом чтении — для error-фазы настроек.
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
