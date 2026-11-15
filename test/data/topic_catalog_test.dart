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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
}
