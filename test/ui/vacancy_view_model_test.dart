import 'dart:async';

import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/domain/question.dart';
import 'package:devmate/ui/vacancy_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

class _ReplySession extends ChangeNotifier implements ChatSession {
  _ReplySession(this.reply);
  final String reply;
  final List<LlmChatMessage> _history = [];

  @override
  List<LlmChatMessage> get history => _history;

  @override
  Stream<String> sendMessageStream(String prompt, {bool retry = false}) async* {
    _history.add(LlmChatMessage(LlmRole.user, prompt));
    _history.add(LlmChatMessage(LlmRole.assistant, reply));
    yield reply;
  }
}

class _GateSession extends ChangeNotifier implements ChatSession {
  final started = Completer<void>();
  final release = Completer<void>();
  final _history = <LlmChatMessage>[];

  @override
  List<LlmChatMessage> get history => _history;

  @override
  Stream<String> sendMessageStream(String prompt, {bool retry = false}) async* {
    _history.add(LlmChatMessage(LlmRole.user, prompt));
    _history.add(LlmChatMessage(LlmRole.assistant, ''));
    started.complete();
    await release.future;
    _history.last.text =
        '{"title":"Ignored","questions":'
        '[{"prompt":"Ignored?","answer":"Ignored."}]}';
    yield _history.last.text;
  }
}

void main() {
  late LlmSettingsRepository settings;
  late TopicCatalog catalog;
  setUp(() async {
    settings = LlmSettingsRepository(storage: MemorySecureStorage());
    await settings.save(
      const LlmSettings(
        baseUrl: 'https://example.com/v1',
        model: 'test',
        apiKey: 'test',
      ),
    );
    catalog = TopicCatalog(
      baseTopics: [
        const InterviewTopic('existing', 'Flutter', 'UI', [
          InterviewQuestion('q0', 'Old?', 'Old answer'),
        ]),
      ],
    );
  });

  test('generates a preview without saving and saves edited questions only on confirmation', () async {
    final model = VacancyViewModel(
      settings: settings,
      catalog: catalog,
      sessionFactory: (_, _) => _ReplySession(
        '{"title":"Job prep","description":"Role",'
        '"questions":[{"prompt":"Original?","answer":"Reference."},'
        '{"prompt":"Remove?","answer":"Unused."}]}',
      ),
    );
    addTearDown(model.dispose);
    await model.generate('job description', 'instruction');
    expect(model.phase, VacancyPhase.preview);
    expect(catalog.topics, hasLength(1));
    model.cancelGeneration();
    expect(model.phase, VacancyPhase.preview);
    expect(model.questions, hasLength(2));
    model.updateQuestion(0, 'Edited?', 'Better reference.');
    model.removeQuestion(1);
    expect(await model.save(title: 'Job prep', description: 'Role'), isTrue);
    expect(catalog.topics, hasLength(2));
    expect(catalog.topicById('existing')!.questions, hasLength(1));
    expect(catalog.topics.last.questions.single.prompt, 'Edited?');
  });

  test(
    'disabling AI mid-generation cancels without creating a preview',
    () async {
      final session = _GateSession();
      final model = VacancyViewModel(
        settings: settings,
        catalog: catalog,
        sessionFactory: (_, _) => session,
      );
      addTearDown(model.dispose);
      final generation = model.generate('job', 'instruction');
      await session.started.future;
      model.cancelGeneration();
      session.release.complete();
      await generation;
      expect(model.phase, VacancyPhase.idle);
      expect(model.draft, isNull);
      expect(model.questions, isEmpty);
      expect(catalog.topics, hasLength(1));
    },
  );

  test(
    'can append to existing topic and invalid output preserves input for retry',
    () async {
      var reply = 'not json';
      final model = VacancyViewModel(
        settings: settings,
        catalog: catalog,
        sessionFactory: (_, _) => _ReplySession(reply),
      );
      addTearDown(model.dispose);
      await model.generate('job', 'instruction');
      expect(model.phase, VacancyPhase.idle);
      expect(model.error, isNotNull);
      reply = '{"questions":[{"prompt":"New?","answer":"Yes."}]}';
      await model.generate('job', 'instruction');
      expect(model.phase, VacancyPhase.preview);
      expect(await model.save(topicId: 'existing'), isTrue);
      expect(catalog.topicById('existing')!.questions, hasLength(2));
    },
  );
}
