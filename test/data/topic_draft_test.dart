import 'package:devmate/data/topic_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('голый JSON-объект парсится', () {
    const text =
        '{"title":"Основы Git","description":"Система контроля версий",'
        '"questions":[{"prompt":"Что такое коммит?","answer":"Снимок состояния."}]}';
    final draft = parseTopicDraft(text);
    expect(draft, isNotNull);
    expect(draft!.title, 'Основы Git');
    expect(draft.description, 'Система контроля версий');
    expect(draft.questions.single, ('Что такое коммит?', 'Снимок состояния.'));
  });

  test('JSON в markdown-фенсе парсится с пояснениями вокруг', () {
    const text =
        'Вот тема:\n```json\n{"title":"SQL","description":"",'
        '"questions":[{"prompt":"Индекс?","answer":"Ускоряет поиск."}]}\n```\n'
        'Подойдёт?';
    final draft = parseTopicDraft(text);
    expect(draft, isNotNull);
    expect(draft!.title, 'SQL');
    expect(draft.description, isEmpty);
  });

  test('вложенные скобки в ответах не ломают парсинг фенса', () {
    const text =
        '```json\n{"title":"Алгоритмы","description":"O(n)",'
        '"questions":[{"prompt":"Хм {так}?","answer":"Ответ {в} скобках."}]}\n```';
    expect(parseTopicDraft(text), isNotNull);
  });

  test('уточняющий вопрос с фигурными скобками — не черновик', () {
    const text = 'Уточни: уровень junior или middle? Пример кода: {"a": 1}';
    expect(parseTopicDraft(text), isNull);
  });

  test('обрезанный JSON и невалидные поля — не черновик', () {
    expect(parseTopicDraft('{"title":"Git","questions":[{"prompt":'), isNull);
    expect(
      parseTopicDraft(
        '{"title":"Git","questions":[{"prompt":"П","answer":""}]}',
      ),
      isNull,
    );
    // Пустой title → draft без названия (append-режим), questions валидны.
    final noTitle = parseTopicDraft(
      '{"title":"","questions":[{"prompt":"П","answer":"О"}]}',
    );
    expect(noTitle, isNotNull);
    expect(noTitle!.title, isNull);
    expect(parseTopicDraft('{"title":"Git","questions":[]}'), isNull);
    expect(parseTopicDraft('["не","объект"]'), isNull);
  });

  test('пробелы обрезаются', () {
    final draft = parseTopicDraft(
      '{"title":"  Git  ","description":"  д  ",'
      '"questions":[{"prompt":"  П  ","answer":"  О  "}]}',
    );
    expect(draft!.title, 'Git');
    expect(draft.questions.single.$1, 'П');
  });

  test('parseAnswerUpdate: fenced с action=update_answer', () {
    const text =
        '```json\n{"action":"update_answer","prompt":"Уточнённый вопрос",'
        '"answer":"Новый эталонный ответ."}\n```';
    final update = parseAnswerUpdate(text);
    expect(update, isNotNull);
    expect(update!.prompt, 'Уточнённый вопрос');
    expect(update.answer, 'Новый эталонный ответ.');
  });

  test('parseAnswerUpdate: без action и с пустыми полями — null', () {
    expect(parseAnswerUpdate('{"prompt":"П","answer":"О"}'), isNull);
    expect(
      parseAnswerUpdate('{"action":"update_answer","prompt":" ","answer":"О"}'),
      isNull,
    );
    expect(parseAnswerUpdate('Уточняющий вопрос без JSON'), isNull);
  });
}
