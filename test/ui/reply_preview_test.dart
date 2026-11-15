import 'package:devmate/data/topic_draft.dart';
import 'package:devmate/ui/reply_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const draftJson =
      '{"title":"Основы Git","description":"Система контроля версий",'
      '"questions":[{"prompt":"Что такое коммит?","answer":"Снимок состояния."},'
      '{"prompt":"Зачем нужен индекс?","answer":"Ускоряет поиск."}]}';

  group('replyPreviewMarkdown', () {
    test('черновик темы целиком в JSON — читаемое превью', () {
      final preview = replyPreviewMarkdown(draftJson);
      expect(preview, isNotNull);
      expect(preview, contains('### Основы Git'));
      expect(preview, contains('Система контроля версий'));
      expect(preview, contains('**1. Что такое коммит?**'));
      expect(preview, contains('**2. Зачем нужен индекс?**'));
      expect(preview, contains('Снимок состояния.'));
      expect(preview, isNot(contains('"questions"')));
      expect(preview, isNot(contains('"prompt"')));
    });

    test('fenced JSON-блок целиком — тоже превью', () {
      final preview = replyPreviewMarkdown('```json\n$draftJson\n```');
      expect(preview, isNotNull);
      expect(preview, contains('**1. Что такое коммит?**'));
    });

    test('обновление ответа — превью с вопросом и новым ответом', () {
      const text =
          '{"action":"update_answer","prompt":"Что такое BuildContext?",'
          '"answer":"Ссылка на виджет в дереве."}';
      final preview = replyPreviewMarkdown(text);
      expect(preview, isNotNull);
      expect(preview, contains('**Что такое BuildContext?**'));
      expect(preview, contains('Ссылка на виджет в дереве.'));
      expect(preview, isNot(contains('"action"')));
    });

    test('обычный текстовый ответ остаётся без изменений', () {
      const text = 'Уточни: какой уровень — junior или middle?';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('проза с фрагментом JSON не заменяется превью', () {
      const text = 'Вот набросок: {"a": 1} — что думаешь?';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('пояснения вокруг fenced-JSON не дают превью', () {
      final text = 'Вот тема:\n```json\n$draftJson\n```\nПодойдёт?';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('JSON без валидных вопросов — без превью', () {
      const text = '{"title":"Git","questions":[{"prompt":"","answer":""}]}';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('пустой список вопросов — без превью (сырой JSON)', () {
      const text = '{"title":"Git","questions":[]}';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('fence-тег в верхнем регистре тоже разворачивается', () {
      final preview = replyPreviewMarkdown('```JSON\n$draftJson\n```');
      expect(preview, isNotNull);
      expect(preview, contains('**1. Что такое коммит?**'));
    });
  });

  group('topicDraftPreviewMarkdown', () {
    test('нумерация вопросов сквозная, без JSON-синтаксиса', () {
      final draft = parseTopicDraft(draftJson)!;
      final preview = topicDraftPreviewMarkdown(draft);
      expect(preview, startsWith('### Основы Git'));
      expect(preview, contains('1. Что такое коммит?'));
      expect(preview, contains('2. Зачем нужен индекс?'));
    });

    test('черновик без заголовка начинается сразу с вопросов', () {
      const text = '{"questions":[{"prompt":"Вопрос?","answer":"Ответ."}]}';
      final preview = topicDraftPreviewMarkdown(parseTopicDraft(text)!);
      expect(preview, startsWith('**1. Вопрос?**'));
      expect(preview, contains('Ответ.'));
    });
  });
}
