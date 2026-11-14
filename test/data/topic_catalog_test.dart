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

      expect(added.id, startsWith('u'));
      expect(added.questions.first.id, added.id.replaceAll('_t0', '_q0'));
      expect(
        added.questions.first.id,
        added.id.replaceRange(added.id.length - 2, null, 'q0'),
      );
      expect(catalog.topics.first.id, 'frontend');
      expect(catalog.topicById(added.id), same(added));
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
