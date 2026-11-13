import 'package:devmate/data/question_catalog.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProgressRepository implements ProgressRepository {
  Map<String, int> stored = {};
  bool failSave = false;

  @override
  Future<Map<String, int>> load() async => {...stored};

  @override
  Future<void> save(Map<String, int> scores) async {
    if (failSave) throw StateError('Storage unavailable');
    stored = {...scores};
  }
}

void main() {
  final question = questionCatalog.first.questions.first;
  test('saves progress and does not farm points on repeats', () async {
    final repository = FakeProgressRepository();
    final model = TrainingViewModel(repository);
    await model.load();
    expect(await model.record(question, knewAnswer: false), isTrue);
    expect(model.points, 5);
    expect(await model.record(question, knewAnswer: false), isTrue);
    expect(model.points, 5);
    expect(await model.record(question, knewAnswer: true), isTrue);
    expect(model.points, 10);
    expect(await model.record(question, knewAnswer: false), isTrue);
    expect(model.points, 10);
    expect(model.completed, 1);
    expect(repository.stored[question.id], 10);
  });

  test('does not report unsaved progress', () async {
    final repository = FakeProgressRepository()..failSave = true;
    final model = TrainingViewModel(repository);
    await model.load();
    expect(await model.record(question, knewAnswer: true), isFalse);
    expect(model.points, 0);
    expect(model.error, isNotNull);
  });

  test('catalog has 10 topics x 12 questions with unique ids and answers', () {
    final ids = <String>{};
    expect(questionCatalog.length, 10);
    for (final topic in questionCatalog) {
      expect(topic.questions.length, 12);
      for (final question in topic.questions) {
        expect(ids.add(question.id), isTrue);
        expect(question.prompt.trim(), isNotEmpty);
        expect(question.answer.trim(), isNotEmpty);
      }
    }
  });
}
