import 'package:devmate/data/topic_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a bare JSON object parses', () {
    const text =
        '{"title":"Git basics","description":"A version control system",'
        '"questions":[{"prompt":"What is a commit?","answer":"A snapshot of the tree."}]}';
    final draft = parseTopicDraft(text);
    expect(draft, isNotNull);
    expect(draft!.title, 'Git basics');
    expect(draft.description, 'A version control system');
    expect(draft.questions.single, (
      'What is a commit?',
      'A snapshot of the tree.',
    ));
  });

  test('JSON in a markdown fence parses with prose around it', () {
    const text =
        'Here is a topic:\n```json\n{"title":"SQL","description":"",'
        '"questions":[{"prompt":"Index?","answer":"It speeds up lookups."}]}\n```\n'
        'Works for you?';
    final draft = parseTopicDraft(text);
    expect(draft, isNotNull);
    expect(draft!.title, 'SQL');
    expect(draft.description, isEmpty);
  });

  test('nested braces in answers do not break fence parsing', () {
    const text =
        '```json\n{"title":"Algorithms","description":"O(n)",'
        '"questions":[{"prompt":"Hmm {like this}?","answer":"An answer {in} braces."}]}\n```';
    expect(parseTopicDraft(text), isNotNull);
  });

  test('a clarifying question with braces is not a draft', () {
    const text = 'Clarify: junior or middle level? Code sample: {"a": 1}';
    expect(parseTopicDraft(text), isNull);
  });

  test('truncated JSON and invalid fields are not a draft', () {
    expect(parseTopicDraft('{"title":"Git","questions":[{"prompt":'), isNull);
    expect(
      parseTopicDraft(
        '{"title":"Git","questions":[{"prompt":"Q","answer":""}]}',
      ),
      isNull,
    );

    final noTitle = parseTopicDraft(
      '{"title":"","questions":[{"prompt":"Q","answer":"A"}]}',
    );
    expect(noTitle, isNotNull);
    expect(noTitle!.title, isNull);
    expect(parseTopicDraft('{"title":"Git","questions":[]}'), isNull);
    expect(parseTopicDraft('["not","an object"]'), isNull);
  });

  test('whitespace is trimmed', () {
    final draft = parseTopicDraft(
      '{"title":"  Git  ","description":"  d  ",'
      '"questions":[{"prompt":"  Q  ","answer":"  A  "}]}',
    );
    expect(draft!.title, 'Git');
    expect(draft.questions.single.$1, 'Q');
  });

  test('parseAnswerUpdate: fenced with action=update_answer', () {
    const text =
        '```json\n{"action":"update_answer","prompt":"Refined question",'
        '"answer":"New reference answer."}\n```';
    final update = parseAnswerUpdate(text);
    expect(update, isNotNull);
    expect(update!.prompt, 'Refined question');
    expect(update.answer, 'New reference answer.');
  });

  test('parseAnswerUpdate: missing action or empty fields yield null', () {
    expect(parseAnswerUpdate('{"prompt":"Q","answer":"A"}'), isNull);
    expect(
      parseAnswerUpdate('{"action":"update_answer","prompt":" ","answer":"A"}'),
      isNull,
    );
    expect(parseAnswerUpdate('A clarifying question without JSON'), isNull);
  });
}
