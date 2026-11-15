import 'package:devmate/data/topic_draft.dart';
import 'package:devmate/ui/reply_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const draftJson =
      '{"title":"Git basics","description":"A version control system",'
      '"questions":[{"prompt":"What is a commit?","answer":"A snapshot of the tree."},'
      '{"prompt":"Why do you need an index?","answer":"It speeds up lookups."}]}';

  group('replyPreviewMarkdown', () {
    test('a topic draft as one JSON object renders as a readable preview', () {
      final preview = replyPreviewMarkdown(draftJson);
      expect(preview, isNotNull);
      expect(preview, contains('### Git basics'));
      expect(preview, contains('A version control system'));
      expect(preview, contains('**1. What is a commit?**'));
      expect(preview, contains('**2. Why do you need an index?**'));
      expect(preview, contains('A snapshot of the tree.'));
      expect(preview, isNot(contains('"questions"')));
      expect(preview, isNot(contains('"prompt"')));
    });

    test(
      'a fenced JSON block spanning the whole reply also gets a preview',
      () {
        final preview = replyPreviewMarkdown('```json\n$draftJson\n```');
        expect(preview, isNotNull);
        expect(preview, contains('**1. What is a commit?**'));
      },
    );

    test('an answer update renders as question plus new answer', () {
      const text =
          '{"action":"update_answer","prompt":"What is BuildContext?",'
          '"answer":"A handle to the widget in the tree."}';
      final preview = replyPreviewMarkdown(text);
      expect(preview, isNotNull);
      expect(preview, contains('**What is BuildContext?**'));
      expect(preview, contains('A handle to the widget in the tree.'));
      expect(preview, isNot(contains('"action"')));
    });

    test('a plain text reply stays unchanged', () {
      const text = 'Clarify: junior or middle level?';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('prose with a JSON fragment is not replaced by a preview', () {
      const text = 'Here is a sketch: {"a": 1} — what do you think?';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('prose around a fenced JSON block yields no preview', () {
      final text = 'Here is a topic:\n```json\n$draftJson\n```\nWorks for you?';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('JSON without valid questions yields no preview', () {
      const text = '{"title":"Git","questions":[{"prompt":"","answer":""}]}';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('an empty question list yields no preview (raw JSON)', () {
      const text = '{"title":"Git","questions":[]}';
      expect(replyPreviewMarkdown(text), isNull);
    });

    test('an uppercase fence tag is unwrapped too', () {
      final preview = replyPreviewMarkdown('```JSON\n$draftJson\n```');
      expect(preview, isNotNull);
      expect(preview, contains('**1. What is a commit?**'));
    });
  });

  group('topicDraftPreviewMarkdown', () {
    test('questions are numbered through, no JSON syntax remains', () {
      final draft = parseTopicDraft(draftJson)!;
      final preview = topicDraftPreviewMarkdown(draft);
      expect(preview, startsWith('### Git basics'));
      expect(preview, contains('1. What is a commit?'));
      expect(preview, contains('2. Why do you need an index?'));
    });

    test('a title-less draft starts straight with the questions', () {
      const text = '{"questions":[{"prompt":"Question?","answer":"Answer."}]}';
      final preview = topicDraftPreviewMarkdown(parseTopicDraft(text)!);
      expect(preview, startsWith('**1. Question?**'));
      expect(preview, contains('Answer.'));
    });
  });
}
