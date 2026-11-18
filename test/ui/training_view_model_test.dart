import 'dart:async';

import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/question_catalog.dart';
import 'package:devmate/data/topic_catalog.dart';
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

class DelayedProgressRepository extends FakeProgressRepository {
  final gate = Completer<void>();
  @override
  Future<void> save(Map<String, int> scores) async {
    if (scores.isNotEmpty) await gate.future;
    await super.save(scores);
  }
}

class PausedResetRepository extends FakeProgressRepository {
  final resume = Completer<void>();
  bool pauseEmpty = true;
  int saveCalls = 0;

  @override
  Future<void> save(Map<String, int> scores) async {
    if (scores.isEmpty && pauseEmpty) await resume.future;
    saveCalls++;
    await super.save(scores);
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

  test('reset waits for in-flight score save and clears it', () async {
    final repository = DelayedProgressRepository();
    final model = TrainingViewModel(repository);
    await model.load();
    final recording = model.record(question, knewAnswer: true);
    final resetting = model.resetProgress();
    expect(await model.record(question, knewAnswer: false), isFalse);
    repository.gate.complete();
    await recording;
    await resetting;
    expect(repository.stored, isEmpty);
    expect(model.completed, 0);
  });

  test('record during reset is queued and persists after reset', () async {
    final repository = PausedResetRepository();
    final model = TrainingViewModel(repository);
    await model.load();
    final reset = model.resetProgress();
    final recorded = model.record(question, knewAnswer: true);
    repository.resume.complete();
    await reset;
    expect(await recorded, isTrue);
    expect(repository.stored[question.id], 10);
    expect(model.error, isNull);
  });

  test('concurrent resets are not silently dropped', () async {
    final repository = PausedResetRepository();
    final model = TrainingViewModel(repository);
    await model.load();
    final global = model.resetProgress();
    final topic = model.resetTopicProgress(questionCatalog.first);
    repository.resume.complete();
    await Future.wait([global, topic]);
    expect(repository.saveCalls, 2);
    expect(repository.stored, isEmpty);
  });

  test(
    'resetTopicProgress clears only selected topic, persists and reloads',
    () async {
      final repository = FakeProgressRepository();
      final model = TrainingViewModel(repository);
      await model.load();
      final first = questionCatalog.first;
      final other = questionCatalog[1];
      await model.record(first.questions.first, knewAnswer: true);
      await model.record(first.questions[1], knewAnswer: false);
      await model.record(other.questions.first, knewAnswer: true);

      await model.resetTopicProgress(first);
      expect(model.completedIn(first), 0);
      expect(model.completedIn(other), 1);
      expect(model.points, 10);
      expect(repository.stored.keys, [other.questions.first.id]);
      final reloaded = TrainingViewModel(repository);
      await reloaded.load();
      expect(reloaded.completedIn(first), 0);
      expect(reloaded.completedIn(other), 1);
    },
  );

  test('reset prunes scores for questions deleted mid-session', () async {
    final repo = FakeProgressRepository();
    final catalog = TopicCatalog();
    final model = TrainingViewModel(repo, catalogRepository: catalog);
    await model.load();
    final deleted = catalog.topics.first.questions.first;
    final kept = catalog.topics[1].questions.first;
    await model.record(deleted, knewAnswer: true);
    await model.record(kept, knewAnswer: false);
    await catalog.deleteQuestion(deleted.id);
    await model.resetTopicProgress(catalog.topics[2]);
    expect(repo.stored.keys, [kept.id]);
    expect(model.completed, 1);
  });

  test('record cannot recreate orphan for deleted question', () async {
    final repo = FakeProgressRepository();
    final catalog = TopicCatalog();
    final model = TrainingViewModel(repo, catalogRepository: catalog);
    await model.load();
    final deleted = catalog.topics.first.questions.first;
    await catalog.deleteQuestion(deleted.id);
    expect(await model.record(deleted, knewAnswer: true), isFalse);
    expect(repo.stored, isEmpty);
    expect(model.completed, 0);
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

  test('load cleans up scores of removed questions', () async {
    final repo = FakeProgressRepository();
    repo.stored = {'fe-1': 10, 'deleted-junk': 5};
    final catalog = TopicCatalog();
    final model = TrainingViewModel(repo, catalogRepository: catalog);
    await model.load();

    expect(model.completed, 1);
    expect(model.points, 10);
  });
}
