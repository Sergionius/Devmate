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
    await catalog.addUserTopic('Docker', 'Контейнеры', [('Образ?', 'Шаблон.')]);
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

  test('экспорт темы без описания можно импортировать обратно', () async {
    final catalog = TopicCatalog();
    await catalog.addUserTopic('Docker', '', [('Образ?', 'Шаблон.')]);
    final json = catalog.exportJson();
    final restored = TopicCatalog();
    await restored.importJson(json);
    expect(restored.topics.last.description, isEmpty);
    expect(restored.topics.last.questions.single.prompt, 'Образ?');
  });

  test(
    'addUserTopic строит уникальные u-префиксованные id и персистит',
    () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();

      final added = await catalog.addUserTopic('Docker', 'Основы контейнеров', [
        ('Что такое образ?', 'Шаблон файловой системы.'),
        ('Чем контейнер отличается от VM?', 'Общий кернел.'),
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
    },
  );

  test('load восстанавливает темы из JSON хранилища', () async {
    final repo = MemoryUserTopics();
    repo.stored = [
      {
        'id': 'u123_t0',
        'title': 'SQL',
        'description': 'Запросы',
        'questions': [
          {
            'id': 'u123_q0',
            'prompt': 'Что такое индекс?',
            'answer': 'Структура для быстрого поиска.',
          },
        ],
      },
      {'broken': true},
    ];
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    expect(catalog.topicById('u123_t0'), isNotNull);
    final topic = catalog.topicById('u123_t0')!;
    expect(topic.questions.single.prompt, 'Что такое индекс?');
    expect(catalog.hasTitle('sql'), isTrue);
    expect(catalog.hasTitle('Без вопросов'), isFalse);
  });

  test(
    'addQuestionsToTopic дополняет встроенную тему и персистит extras',
    () async {
      final repo = MemoryUserTopics();
      final catalog = TopicCatalog(userTopicsRepository: repo);
      await catalog.load();
      final before = catalog.topicById('frontend')!;

      await catalog.addQuestionsToTopic('frontend', [
        ('Новый вопрос?', 'Новый ответ.'),
        ('Ещё вопрос?', 'Ещё ответ.'),
      ]);

      final merged = catalog.topicById('frontend')!;
      expect(merged.questions, hasLength(before.questions.length + 2));
      expect(merged.questions.last.prompt, 'Ещё вопрос?');

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

  test('овереи правят встроенные вопросы, темы и удаляют вопросы', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    await catalog.updateQuestion(
      'fe-1',
      'Правленный вопрос',
      'Правленный ответ',
    );
    final frontend = catalog.topicById('frontend')!;
    final edited = frontend.questions.firstWhere((q) => q.id == 'fe-1');
    expect(edited.prompt, 'Правленный вопрос');
    expect(edited.answer, 'Правленный ответ');

    expect(repo.overridesStored['questionEdits'], isNotNull);
    expect(
      questionCatalog
          .firstWhere((t) => t.id == 'frontend')
          .questions
          .first
          .prompt,
      'Что происходит после ввода URL в браузере?',
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

    await catalog.updateTopicMeta('frontend', 'Frontend (новый)', 'Обновлено');
    expect(catalog.topicById('frontend')!.title, 'Frontend (новый)');
    expect(repo.overridesStored['topicEdits'], isNotNull);
  });

  test('оверлеи применяются к добавленным вопросам встроенной темы', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    await catalog.addQuestionsToTopic('frontend', [
      ('Доп. вопрос про кеш', 'Доп. ответ про кеш.'),
    ]);
    final withExtra = catalog.topicById('frontend')!;
    expect(withExtra.questions.last.prompt, 'Доп. вопрос про кеш');

    await catalog.updateQuestion(
      withExtra.questions.last.id,
      'Правленный доп. вопрос',
      'Правленный доп. ответ.',
    );
    final merged = catalog.topicById('frontend')!;
    expect(merged.questions.last.prompt, 'Правленный доп. вопрос');
    expect(merged.questions.last.answer, 'Правленный доп. ответ.');

    await catalog.deleteQuestion(merged.questions.last.id);
    final afterDelete = catalog.topicById('frontend')!;
    expect(
      afterDelete.questions.map((q) => q.prompt),
      isNot(contains('Правленный доп. вопрос')),
    );
  });

  test('правка пользовательского вопроса идёт напрямую в тему', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();
    final created = await catalog.addUserTopic('Моя тема', '', [
      ('Вопрос до правки', 'Ответ до правки'),
    ]);

    await catalog.updateQuestion(
      created.questions.first.id,
      'Вопрос после правки',
      'Ответ после правки',
    );

    final stored = repo.stored.single;
    expect(
      (stored['questions'] as List).first['prompt'],
      'Вопрос после правки',
    );
    final edits = repo.overridesStored['questionEdits'] as Map? ?? {};
    expect(edits, isEmpty);
  });

  test('knownQuestionIds покрывает все вопросы каталога и extras', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    final known = catalog.knownQuestionIds;
    expect(known, contains('fe-1'));

    await catalog.addQuestionsToTopic('frontend', [('Ещё один', 'Да')]);
    final frontend = catalog.topicById('frontend')!;
    final addedId = frontend.questions.last.id;
    expect(catalog.knownQuestionIds, contains(addedId));
  });

  test('два добавления подряд в одну тему накапливаются без дублей', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    await catalog.addQuestionsToTopic('frontend', [('Первая пара', 'Ответ 1')]);
    await catalog.addQuestionsToTopic('frontend', [('Вторая пара', 'Ответ 2')]);

    final merged = catalog.topicById('frontend')!;
    final prompts = merged.questions.map((q) => q.prompt).toList();
    expect(prompts, contains('Первая пара'));
    expect(prompts, contains('Вторая пара'));
    final ids = merged.questions.map((q) => q.id).toSet();
    expect(ids.length, merged.questions.length);
    expect(repo.extraStored['frontend'], hasLength(2));
  });

  test('addQuestionsToTopic в пользовательской теме сохраняет исходные вопросы и не дублирует через extras', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();
    final created = await catalog.addUserTopic('Моя тема', '', [
      ('Исходный вопрос', 'Исходный ответ'),
    ]);

    await catalog.addQuestionsToTopic(created.id, [
      ('Добавленный вопрос', 'Добавленный ответ'),
    ]);

    final topic = catalog.topicById(created.id)!;
    expect(topic.questions, hasLength(2));
    expect(topic.questions.map((q) => q.prompt), [
      'Исходный вопрос',
      'Добавленный вопрос',
    ]);

    expect(repo.extraStored[created.id], isNull);

    final second = TopicCatalog(userTopicsRepository: repo);
    await second.load();
    final restored = second.topicById(created.id)!;
    expect(restored.questions.map((q) => q.prompt), [
      'Исходный вопрос',
      'Добавленный вопрос',
    ]);
  });
}
