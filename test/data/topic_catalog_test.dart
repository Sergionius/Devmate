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
      // id новых вопросов уникальны и не пересекаются со встроенными.
      final ids = merged.questions.map((q) => q.id).toSet();
      expect(ids.length, merged.questions.length);
      expect(ids, containsAll(<String>[...before.questions.map((q) => q.id)]));
      // extras персистятся отдельно: {frontend: [2 вопроса]}.
      expect(repo.extraStored['frontend'], hasLength(2));
      // round-trip: новая инстанс каталога восстанавливает merged-состояние.
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

    // Правка встроенного вопроса (оверей, не мутирует каталог).
    await catalog.updateQuestion(
      'fe-1',
      'Правленный вопрос',
      'Правленный ответ',
    );
    final frontend = catalog.topicById('frontend')!;
    final edited = frontend.questions.firstWhere((q) => q.id == 'fe-1');
    expect(edited.prompt, 'Правленный вопрос');
    expect(edited.answer, 'Правленный ответ');
    // Оверлей сохранён, компилируемая база не изменилась.
    expect(repo.overridesStored['questionEdits'], isNotNull);
    expect(
      questionCatalog // базовый каталог не тронут
          .firstWhere((t) => t.id == 'frontend')
          .questions
          .first
          .prompt,
      'Что происходит после ввода URL в браузере?',
    );

    // Возврат к исходному тексту снимает оверлей.
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

    // Удаление встроенного вопроса.
    await catalog.deleteQuestion('fe-2');
    final afterDelete = catalog.topicById('frontend')!;
    expect(afterDelete.questions.map((q) => q.id), isNot(contains('fe-2')));
    expect(repo.overridesStored['deletedQuestionIds'], contains('fe-2'));

    // Правка метаданных темы.
    await catalog.updateTopicMeta('frontend', 'Frontend (новый)', 'Обновлено');
    expect(catalog.topicById('frontend')!.title, 'Frontend (новый)');
    expect(repo.overridesStored['topicEdits'], isNotNull);
  });

  test('оверлеи применяются к добавленным вопросам встроенной темы', () async {
    final repo = MemoryUserTopics();
    final catalog = TopicCatalog(userTopicsRepository: repo);
    await catalog.load();

    // Добавляем вопрос во встроенную тему (extras map).
    await catalog.addQuestionsToTopic('frontend', [
      ('Доп. вопрос про кеш', 'Доп. ответ про кеш.'),
    ]);
    final withExtra = catalog.topicById('frontend')!;
    expect(withExtra.questions.last.prompt, 'Доп. вопрос про кеш');

    // Правим добавленный вопрос (questionEdits) — правка должна применяться
    // (композиция: сначала extras, потом оверлеи).
    await catalog.updateQuestion(
      withExtra.questions.last.id,
      'Правленный доп. вопрос',
      'Правленный доп. ответ.',
    );
    final merged = catalog.topicById('frontend')!;
    expect(merged.questions.last.prompt, 'Правленный доп. вопрос');
    expect(merged.questions.last.answer, 'Правленный доп. ответ.');

    // Удаляем добавленный вопрос — он исчезает (удаление по оверлею).
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
    // extras map для user-темы не используется — вопросы живут в самой теме.
    expect(repo.extraStored[created.id], isNull);
    // round-trip: исходные вопросы не потеряны после persist.
    final second = TopicCatalog(userTopicsRepository: repo);
    await second.load();
    final restored = second.topicById(created.id)!;
    expect(restored.questions.map((q) => q.prompt), [
      'Исходный вопрос',
      'Добавленный вопрос',
    ]);
  });
}
