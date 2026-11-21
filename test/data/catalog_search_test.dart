import 'package:devmate/data/catalog_search.dart';
import 'package:devmate/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = [
    InterviewTopic('flutter', 'Flutter', 'Mobile UI', [
      InterviewQuestion(
        'q1',
        'What is a Widget?',
        'An immutable UI description.',
      ),
      InterviewQuestion(
        'q2',
        'What is a State?',
        'A mutable part of a widget.',
      ),
    ]),
    InterviewTopic('other', 'Algorithms', 'Data structures', [
      InterviewQuestion('q3', 'What is a tree?', 'A hierarchical structure.'),
    ]),
  ];

  test('empty query returns no results', () {
    final result = searchCatalog(catalog, '  ');
    expect(result.topics, isEmpty);
    expect(result.questions, isEmpty);
  });

  test('finds topic titles and descriptions regardless of case', () {
    expect(searchCatalog(catalog, 'FLUTTER').topics.single.id, 'flutter');
    expect(searchCatalog(catalog, 'data structures').topics.single.id, 'other');
  });

  test('finds question prompts and retains the navigable index', () {
    final hit = searchCatalog(catalog, 'what  STATE').questions.single;
    expect(hit.question.id, 'q2');
    expect(hit.index, 1);
    expect(hit.inAnswer, isFalse);
  });

  test('matches answers only when the separate filter is enabled', () {
    expect(searchCatalog(catalog, 'hierarchical').questions, isEmpty);
    final hit = searchCatalog(
      catalog,
      'hierarchical',
      includeAnswers: true,
    ).questions.single;
    expect(hit.question.id, 'q3');
    expect(hit.inAnswer, isTrue);
  });

  test('does not duplicate prompt matches when answer also matches', () {
    final hit = searchCatalog(
      catalog,
      'widget',
      includeAnswers: true,
    ).questions;
    expect(hit.length, 2);
    expect(hit.first.inAnswer, isFalse);
  });
}
