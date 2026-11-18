import 'dart:async';

import 'package:devmate/data/question_catalog.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryUserTopics implements UserTopicsRepository {
  List<Map<String, dynamic>> stored = [];
  Map<String, List<Map<String, dynamic>>> extraStored = {};

  @override
  Future<List<Map<String, dynamic>>> load() async => stored;

  @override
  Future<void> save(List<Map<String, dynamic>> topics) async {
    stored = topics;
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> loadExtra() async =>
      extraStored;

  @override
  Future<void> saveExtra(Map<String, List<Map<String, dynamic>>> extra) async {
    extraStored = extra;
  }

  Map<String, dynamic> overridesStored = {};

  @override
  Future<Map<String, dynamic>> loadOverrides() async => overridesStored;

  @override
  Future<void> saveOverrides(Map<String, dynamic> overrides) async {
    overridesStored = overrides;
  }
}

class FailingUserTopics extends MemoryUserTopics {
  bool fail = true;

  void _check() {
    if (fail) throw StateError('Storage unavailable');
  }

  @override
  Future<void> save(List<Map<String, dynamic>> topics) async {
    _check();
    await super.save(topics);
  }

  @override
  Future<void> saveExtra(Map<String, List<Map<String, dynamic>>> extra) async {
    _check();
    await super.saveExtra(extra);
  }

  @override
  Future<void> saveOverrides(Map<String, dynamic> overrides) async {
    _check();
    await super.saveOverrides(overrides);
  }
}

class PausedUserTopics extends MemoryUserTopics {
  final gate = Completer<void>();
  final started = Completer<void>();

  @override
  Future<void> save(List<Map<String, dynamic>> topics) async {
    if (topics.isNotEmpty && !gate.isCompleted) {
      if (!started.isCompleted) started.complete();
      await gate.future;
    }
    await super.save(topics);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reset waits for an in-flight topic save', () async {
    final repo = PausedUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo, baseTopics: []);
    final adding = catalog.addUserTopic('Temporary', '', []);
    await repo.started.future;
    final resetting = catalog.reset();
    repo.gate.complete();
    await Future.wait([adding, resetting]);
    expect(catalog.topics, isEmpty);
    expect(repo.stored, isEmpty);
  });

  test('empty manual topic survives reload and JSON export/import', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    final added = await catalog.addUserTopic(
      'Empty',
      'Add questions later',
      [],
    );
    final reloaded = TopicCatalog(userTopicsRepository: repo);
    await reloaded.load();
    expect(reloaded.topicById(added.id)?.questions, isEmpty);
    final imported = TopicCatalog();
    await imported.importJson(reloaded.exportJson());
    expect(imported.topics.last.title, 'Empty');
    expect(imported.topics.last.questions, isEmpty);
  });

  test('parallel topic creations retain both saved topics', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await Future.wait([
      catalog.addUserTopic('First', '', []),
      catalog.addUserTopic('Second', '', []),
    ]);
    expect(repo.stored.map((topic) => topic['title']), ['First', 'Second']);
    final reloaded = TopicCatalog(userTopicsRepository: repo);
    await reloaded.load();
    expect(reloaded.hasTitle('First'), isTrue);
    expect(reloaded.hasTitle('Second'), isTrue);
  });

  test('failed writes do not change the visible catalog', () async {
    final repo = FailingUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    final original = catalog.topics.first;
    await expectLater(catalog.addUserTopic('New', '', []), throwsStateError);
    expect(catalog.hasTitle('New'), isFalse);
    await expectLater(
      catalog.addQuestionsToTopic(original.id, [('New?', 'Answer')]),
      throwsStateError,
    );
    expect(
      catalog.topicById(original.id)!.questions.length,
      original.questions.length,
    );
    await expectLater(
      catalog.updateTopicMeta(original.id, 'Changed', ''),
      throwsStateError,
    );
    expect(catalog.topicById(original.id)!.title, original.title);
    await expectLater(
      catalog.updateQuestion(original.questions.first.id, 'Changed?', 'Answer'),
      throwsStateError,
    );
    expect(
      catalog.topicById(original.id)!.questions.first.prompt,
      original.questions.first.prompt,
    );
    await expectLater(
      catalog.deleteQuestion(original.questions.first.id),
      throwsStateError,
    );
    expect(
      catalog.topicById(original.id)!.questions.length,
      original.questions.length,
    );

    repo.fail = false;
    final userTopic = await catalog.addUserTopic('Own', '', [
      ('Own?', 'Answer'),
    ]);
    repo.fail = true;
    await expectLater(
      catalog.addQuestionsToTopic(userTopic.id, [('Extra?', 'Answer')]),
      throwsStateError,
    );
    await expectLater(
      catalog.updateQuestion(
        userTopic.questions.first.id,
        'Changed?',
        'Answer',
      ),
      throwsStateError,
    );
    await expectLater(
      catalog.deleteQuestion(userTopic.questions.first.id),
      throwsStateError,
    );
    await expectLater(
      catalog.updateTopicMeta(userTopic.id, 'Renamed', ''),
      throwsStateError,
    );
    expect(catalog.topicById(userTopic.id)!.title, 'Own');
    expect(catalog.topicById(userTopic.id)!.questions.single.prompt, 'Own?');
    expect(repo.stored.single['title'], 'Own');
  });

  test(
    'English catalog mirrors Russian ids for stable progress and overrides',
    () {
      expect(questionCatalogEn.length, questionCatalogRu.length);
      for (var i = 0; i < questionCatalogRu.length; i++) {
        expect(questionCatalogEn[i].id, questionCatalogRu[i].id);
        expect(
          questionCatalogEn[i].questions.length,
          questionCatalogRu[i].questions.length,
        );
        for (var j = 0; j < questionCatalogRu[i].questions.length; j++) {
          expect(
            questionCatalogEn[i].questions[j].id,
            questionCatalogRu[i].questions[j].id,
          );
          expect(questionCatalogEn[i].questions[j].prompt, isNot(''));
          expect(questionCatalogEn[i].questions[j].answer, isNot(''));
        }
      }
    },
  );

  test('JSON roundtrip replaces catalog, rejects malformed input, reset restores builtins', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();
    final original = catalog.topicById('frontend')!;
    await catalog.addUserTopic('Docker', 'Containers', [
      ('Image?', 'A template.'),
    ]);
    final json = catalog.exportJson();
    await catalog.importJson(json);
    expect(catalog.topics.length, 11);
    expect(catalog.topics.first.title, 'Frontend');
    expect(
      catalog.topics.first.questions.first.prompt,
      original.questions.first.prompt,
    );
    final before = catalog.exportJson();
    await expectLater(
      catalog.importJson(
        '{"version":1,"topics":[{"title":"X","description":"D","questions":[{"prompt":"P"}]}]}',
      ),
      throwsFormatException,
    );
    expect(catalog.exportJson(), before);
    await catalog.reset();
    expect(catalog.topics.length, 10);
    expect(
      catalog.topicById('frontend')!.questions.length,
      original.questions.length,
    );
    expect(repo.stored, isEmpty);
    expect(repo.extraStored, isEmpty);
    expect(repo.overridesStored, isEmpty);
    final reloaded = TopicCatalog(userTopicsRepository: repo);
    await reloaded.load();
    expect(reloaded.topics.length, 10);
  });

  test('exporting a topic without description imports back fine', () async {
    final catalog = TopicCatalog();
    await catalog.addUserTopic('Docker', '', [('Image?', 'A template.')]);
    final json = catalog.exportJson();
    final restored = TopicCatalog();
    await restored.importJson(json);
    expect(restored.topics.last.description, isEmpty);
    expect(restored.topics.last.questions.single.prompt, 'Image?');
  });

  test('addUserTopic builds unique u-prefixed ids and persists', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    final added = await catalog.addUserTopic('Docker', 'Container basics', [
      ('What is an image?', 'A filesystem template.'),
      ('How is a container different from a VM?', 'A shared kernel.'),
    ]);

    expect(added.questions.first.id, isNot(added.id));
    expect(catalog.topics.first.id, 'frontend');
    final found = catalog.topicById(added.id)!;
    expect(found.title, 'Docker');
    expect(found.questions, hasLength(2));
    expect(catalog.hasTitle('docker'), isTrue);
    expect(catalog.hasTitle('Frontend'), isTrue);

    final persisted = repo.stored.single;
    expect(persisted['id'], added.id);
    expect((persisted['questions'] as List).length, 2);
  });

  test('load restores topics from the JSON store', () async {
    final repo = MemoryUserTopics();
    repo.stored = [
      {
        'id': 'u123_t0',
        'title': 'SQL',
        'description': 'Queries',
        'questions': [
          {
            'id': 'u123_q0',
            'prompt': 'What is an index?',
            'answer': 'A structure for fast lookups.',
          },
        ],
      },
      {'broken': true},
    ];
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    expect(catalog.topicById('u123_t0'), isNotNull);
    final topic = catalog.topicById('u123_t0')!;
    expect(topic.questions.single.prompt, 'What is an index?');
    expect(catalog.hasTitle('sql'), isTrue);
    expect(catalog.hasTitle('No questions'), isFalse);
  });

  test(
    'addQuestionsToTopic extends a built-in topic and persists extras',
    () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();
      final before = catalog.topicById('frontend')!;

      await catalog.addQuestionsToTopic('frontend', [
        ('A new question?', 'A new answer.'),
        ('Another question?', 'Another answer.'),
      ]);

      final merged = catalog.topicById('frontend')!;
      expect(merged.questions, hasLength(before.questions.length + 2));
      expect(merged.questions.last.prompt, 'Another question?');

      final ids = merged.questions.map((q) => q.id).toSet();
      expect(ids.length, merged.questions.length);
      expect(ids, containsAll(<String>[...before.questions.map((q) => q.id)]));

      expect(repo.extraStored['frontend'], hasLength(2));

      final second = TopicCatalog(userTopicsRepository: repo);
      await second.load();
      expect(
        second.topicById('frontend')!.questions,
        hasLength(before.questions.length + 2),
      );
    },
  );

  test(
    'overrides edit built-in questions and topics, and delete questions',
    () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();

      final frontendBefore = catalog.topicById('frontend')!;
      final builtinPrompt = frontendBefore.questions.first.prompt;

      await catalog.updateQuestion(
        'fe-1',
        'An edited question',
        'An edited answer',
      );
      final frontend = catalog.topicById('frontend')!;
      final edited = frontend.questions.firstWhere((q) => q.id == 'fe-1');
      expect(edited.prompt, 'An edited question');
      expect(edited.answer, 'An edited answer');

      expect(repo.overridesStored['questionEdits'], isNotNull);
      expect(
        // Built-in constant must stay untouched by overrides.
        questionCatalog
            .firstWhere((t) => t.id == 'frontend')
            .questions
            .first
            .prompt,
        builtinPrompt,
      );

      final baseQuestion = questionCatalog
          .firstWhere((t) => t.id == 'frontend')
          .questions
          .firstWhere((q) => q.id == 'fe-1');
      await catalog.updateQuestion(
        'fe-1',
        baseQuestion.prompt,
        baseQuestion.answer,
      );
      final editsAfter = repo.overridesStored['questionEdits'] as Map?;
      expect(editsAfter?['fe-1'], isNull);

      await catalog.deleteQuestion('fe-2');
      final afterDelete = catalog.topicById('frontend')!;
      expect(afterDelete.questions.map((q) => q.id), isNot(contains('fe-2')));
      expect(repo.overridesStored['deletedQuestionIds'], contains('fe-2'));

      await catalog.updateTopicMeta('frontend', 'Frontend (edited)', 'Updated');
      expect(catalog.topicById('frontend')!.title, 'Frontend (edited)');
      expect(repo.overridesStored['topicEdits'], isNotNull);
    },
  );

  test('overrides apply to questions added to a built-in topic', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    await catalog.addQuestionsToTopic('frontend', [
      ('An extra cache question', 'An extra cache answer.'),
    ]);
    final withExtra = catalog.topicById('frontend')!;
    expect(withExtra.questions.last.prompt, 'An extra cache question');

    await catalog.updateQuestion(
      withExtra.questions.last.id,
      'An edited extra question',
      'An edited extra answer.',
    );
    final merged = catalog.topicById('frontend')!;
    expect(merged.questions.last.prompt, 'An edited extra question');
    expect(merged.questions.last.answer, 'An edited extra answer.');

    await catalog.deleteQuestion(merged.questions.last.id);
    final afterDelete = catalog.topicById('frontend')!;
    expect(
      afterDelete.questions.map((q) => q.prompt),
      isNot(contains('An edited extra question')),
    );
  });

  test('editing a user question writes straight into the topic', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();
    final created = await catalog.addUserTopic('My topic', '', [
      ('Question before the edit', 'Answer before the edit'),
    ]);

    await catalog.updateQuestion(
      created.questions.first.id,
      'Question after the edit',
      'Answer after the edit',
    );

    final stored = repo.stored.single;
    expect(
      (stored['questions'] as List).first['prompt'],
      'Question after the edit',
    );
    final edits = repo.overridesStored['questionEdits'] as Map? ?? {};
    expect(edits, isEmpty);
  });

  test('knownQuestionIds covers catalog questions and extras', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    final known = catalog.knownQuestionIds;
    expect(known, contains('fe-1'));

    await catalog.addQuestionsToTopic('frontend', [('One more', 'Yes')]);
    final frontend = catalog.topicById('frontend')!;
    final addedId = frontend.questions.last.id;
    expect(catalog.knownQuestionIds, contains(addedId));
  });

  test('two appends into one topic accumulate without duplicates', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    await catalog.addQuestionsToTopic('frontend', [('First pair', 'Answer 1')]);
    await catalog.addQuestionsToTopic('frontend', [
      ('Second pair', 'Answer 2'),
    ]);

    final merged = catalog.topicById('frontend')!;
    final prompts = merged.questions.map((q) => q.prompt).toList();
    expect(prompts, contains('First pair'));
    expect(prompts, contains('Second pair'));
    final ids = merged.questions.map((q) => q.id).toSet();
    expect(ids.length, merged.questions.length);
    expect(repo.extraStored['frontend'], hasLength(2));
  });

  test('addQuestionsToTopic in a user topic keeps original questions and skips extras', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();
    final created = await catalog.addUserTopic('My topic', '', [
      ('Original question', 'Original answer'),
    ]);

    await catalog.addQuestionsToTopic(created.id, [
      ('Added question', 'Added answer'),
    ]);

    final topic = catalog.topicById(created.id)!;
    expect(topic.questions, hasLength(2));
    expect(topic.questions.map((q) => q.prompt), [
      'Original question',
      'Added question',
    ]);

    expect(repo.extraStored[created.id], isNull);

    final second = TopicCatalog(userTopicsRepository: repo);
    await second.load();
    final restored = second.topicById(created.id)!;
    expect(restored.questions.map((q) => q.prompt), [
      'Original question',
      'Added question',
    ]);
  });

  test(
    'addJson appends to built-in, extends user topic and creates new one',
    () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();
      final docker = await catalog.addUserTopic('Docker', 'Container basics', [
        ('Original docker question', 'Original docker answer'),
      ]);
      await catalog.addQuestionsToTopic('frontend', [
        ('Pre-existing extra', 'Pre-existing extra answer'),
      ]);
      await catalog.updateQuestion('fe-1', 'Edited prompt', 'Edited answer');
      final frontendBefore = catalog.topicById('frontend')!;
      final dockerBefore = catalog.topicById(docker.id)!;

      await catalog.addJson(
        '{"version":1,"topics":['
        '{"title":"  frontend  ","description":"Ignored","questions":['
        '{"id":"ignored-input-id","prompt":"Appended to built-in","answer":"Yes"}]},'
        '{"title":"docker","description":"Ignored","questions":['
        '{"prompt":"Appended to user topic","answer":"Sure"}]},'
        '{"title":"Kubernetes","description":"Orchestration","questions":['
        '{"prompt":"What is a pod?","answer":"Smallest deployable unit."}]}'
        ']}',
      );

      // Built-in topic extended, all existing ids preserved.
      final frontend = catalog.topicById('frontend')!;
      expect(
        frontend.questions,
        hasLength(frontendBefore.questions.length + 1),
      );
      expect(
        frontend.questions.map((q) => q.id),
        containsAll(frontendBefore.questions.map((q) => q.id)),
      );
      expect(frontend.questions.last.prompt, 'Appended to built-in');

      // User topic extended in place, original id and questions preserved.
      final dockerAfter = catalog.topicById(docker.id)!;
      expect(
        dockerAfter.questions,
        hasLength(dockerBefore.questions.length + 1),
      );
      expect(dockerAfter.questions.first.prompt, 'Original docker question');
      expect(dockerAfter.questions.last.prompt, 'Appended to user topic');

      // New topic created with fresh ids.
      final kubernetes = catalog.topics.firstWhere(
        (t) => t.title == 'Kubernetes',
      );
      expect(kubernetes.description, 'Orchestration');
      expect(kubernetes.questions.single.prompt, 'What is a pod?');
      expect(kubernetes.id, isNot('frontend'));
      expect(kubernetes.questions.single.id, isNot('ignored-input-id'));

      // Extras, overrides and built-in topics stay untouched.
      expect(repo.extraStored['frontend'], hasLength(2));
      expect((repo.overridesStored['questionEdits'] as Map)['fe-1'], isNotNull);
      expect(frontend.questions.first.prompt, 'Edited prompt');
      expect(catalog.topicById('javascript'), isNotNull);

      // Everything survives a reload into a fresh catalog.
      final reloaded = TopicCatalog(userTopicsRepository: repo);
      await reloaded.load();
      final restoredFrontend = reloaded.topicById('frontend')!;
      expect(
        restoredFrontend.questions,
        hasLength(frontendBefore.questions.length + 1),
      );
      expect(restoredFrontend.questions.first.prompt, 'Edited prompt');
      expect(restoredFrontend.questions.last.prompt, 'Appended to built-in');
      expect(reloaded.topicById(docker.id)!.questions, hasLength(2));
      expect(
        reloaded.topics
            .firstWhere((t) => t.title == 'Kubernetes')
            .questions
            .single
            .prompt,
        'What is a pod?',
      );
    },
  );

  test(
    'addJson handles duplicate titles sequentially against live catalog',
    () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();

      await catalog.addJson(
        '{"version":1,"topics":['
        '{"title":"Docker","description":"First","questions":['
        '{"prompt":"Q1","answer":"A1"}]},'
        '{"title":"Docker","description":"Second","questions":['
        '{"prompt":"Q2","answer":"A2"}]},'
        '{"title":"frontend","description":"x","questions":['
        '{"prompt":"B1","answer":"BA1"},{"prompt":"B2","answer":"BA2"}]}'
        ']}',
      );

      // First occurrence created the topic, second appended into it.
      expect(catalog.topics.where((t) => t.title == 'Docker'), hasLength(1));
      final docker = catalog.topics.firstWhere((t) => t.title == 'Docker');
      expect(docker.description, 'First');
      expect(docker.questions.map((q) => q.prompt), ['Q1', 'Q2']);

      // Both built-in entries appended to the same visible topic.
      final frontend = catalog.topicById('frontend')!;
      expect(frontend.questions.last.prompt, 'B2');
      expect(repo.extraStored['frontend'], hasLength(2));
    },
  );

  test(
    'addJson rejects invalid JSON without touching catalog or storage',
    () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();
      await catalog.addUserTopic('Docker', '', [('Q', 'A')]);
      await catalog.addQuestionsToTopic('frontend', [
        ('Extra', 'Extra answer'),
      ]);
      final beforeExport = catalog.exportJson();
      final beforeStored = List.of(repo.stored);
      final beforeExtra = Map.of(repo.extraStored);
      final beforeOverrides = Map.of(repo.overridesStored);

      await expectLater(
        catalog.addJson(
          '{"version":1,"topics":[{"title":"X","description":"D","questions":[{"prompt":"P"}]}]}',
        ),
        throwsFormatException,
      );
      await expectLater(catalog.addJson('not json'), throwsFormatException);
      await expectLater(
        catalog.addJson(
          '{"version":2,"topics":[{"title":"X","description":"D","questions":[{"prompt":"P","answer":"A"}]}]}',
        ),
        throwsFormatException,
      );

      expect(catalog.exportJson(), beforeExport);
      expect(repo.stored, beforeStored);
      expect(repo.extraStored, beforeExtra);
      expect(repo.overridesStored, beforeOverrides);
      expect(catalog.topics.where((t) => t.title == 'X'), isEmpty);
    },
  );

  group('restoreJson', () {
    const payload =
        '{"version":1,"topics":[{'
        '"id":"topic-1","title":"Docker","description":"Containers",'
        '"questions":[{'
        '"id":"q-image","prompt":"Image?","answer":"A template."'
        '}]}]}';

    test('preserves topic and question IDs so progress stays valid', () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();
      await catalog.restoreJson(payload);
      final topic = catalog.topicById('topic-1');
      expect(topic, isNotNull);
      expect(topic!.title, 'Docker');
      expect(topic.questions.single.id, 'q-image');
      expect(catalog.knownQuestionIds, contains('q-image'));
      // Built-in questions are hidden, only the restored topics remain.
      expect(catalog.topics.length, 1);
    });

    test('persists IDs so a reload keeps them', () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();
      await catalog.restoreJson(payload);
      final reloaded = TopicCatalog(userTopicsRepository: repo);
      await reloaded.load();
      expect(reloaded.topicById('topic-1')!.questions.single.id, 'q-image');
    });

    test('an empty topics list clears user topics', () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();
      await catalog.addUserTopic('Docker', '', [('Image?', 'A template.')]);
      await catalog.restoreJson('{"version":1,"topics":[]}');
      expect(catalog.topics.where((topic) => topic.title == 'Docker'), isEmpty);
      expect(repo.stored, isEmpty);
    });

    test('rejects duplicate, empty or missing IDs without changes', () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();
      await catalog.restoreJson(payload);
      final before = catalog.exportJson();
      final beforeStored = List.of(repo.stored);

      const duplicateTopic =
          '{"version":1,"topics":['
          '{"id":"t1","title":"A","description":"","questions":[]},'
          '{"id":"t1","title":"B","description":"","questions":[]}]}';
      const duplicateQuestion =
          '{"version":1,"topics":['
          '{"id":"t1","title":"A","description":"","questions":['
          '{"id":"q1","prompt":"P","answer":"A"}]},'
          '{"id":"t2","title":"B","description":"","questions":['
          '{"id":"q1","prompt":"P","answer":"A"}]}]}';
      const emptyId =
          '{"version":1,"topics":['
          '{"id":"","title":"A","description":"","questions":[]}]}';
      const missingQuestionId =
          '{"version":1,"topics":['
          '{"id":"t1","title":"A","description":"","questions":['
          '{"prompt":"P","answer":"A"}]}]}';

      for (final source in [
        duplicateTopic,
        duplicateQuestion,
        emptyId,
        missingQuestionId,
      ]) {
        await expectLater(catalog.restoreJson(source), throwsFormatException);
      }
      expect(catalog.exportJson(), before);
      expect(repo.stored, beforeStored);
    });
  });
}
