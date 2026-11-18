import 'package:flutter/foundation.dart';

import '../data/data_transfer.dart';
import '../data/progress_repository.dart';
import '../data/topic_catalog.dart';
import '../domain/question.dart';

enum TrainingError { progressLoad, answerSave }

class TrainingViewModel extends ChangeNotifier {
  TrainingViewModel(this._repository, {TopicCatalog? catalogRepository})
    : _catalog = catalogRepository;

  final ProgressRepository _repository;
  final TopicCatalog? _catalog;
  Map<String, int> _scores = {};
  bool _loading = true;
  bool _saving = false;
  Future<void> _pendingWrite = Future<void>.value();
  TrainingError? _error;

  bool get loading => _loading;
  bool get saving => _saving;
  TrainingError? get error => _error;
  int get points => _scores.values.fold(0, (sum, value) => sum + value);
  int get completed => _scores.length;
  Map<String, int> get scores => Map.unmodifiable(_scores);
  int completedIn(InterviewTopic topic) => topic.questions
      .where((question) => _scores.containsKey(question.id))
      .length;
  int? scoreFor(InterviewQuestion question) => _scores[question.id];

  Future<void> load() async {
    try {
      _scores = await _repository.load();

      final known = _catalog?.knownQuestionIds;
      if (known != null) {
        _scores = {
          for (final entry in _scores.entries)
            if (known.contains(entry.key)) entry.key: entry.value,
        };
      }
      _error = null;
    } catch (_) {
      _error = TrainingError.progressLoad;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<T> _enqueueWrite<T>(Future<T> Function() write) {
    final result = _pendingWrite.then((_) => write());
    _pendingWrite = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> resetTopicProgress(InterviewTopic topic) =>
      _enqueueWrite(() async {
        final ids = {for (final question in topic.questions) question.id};
        final known = _catalog?.knownQuestionIds;
        final remaining = {
          for (final entry in _scores.entries)
            if (!ids.contains(entry.key) &&
                (known == null || known.contains(entry.key)))
              entry.key: entry.value,
        };
        await _repository.save(remaining);
        _scores = remaining;
        _error = null;
        notifyListeners();
      });

  Future<void> resetProgress() => _enqueueWrite(() async {
    await _repository.save({});
    _scores = {};
    _error = null;
    notifyListeners();
  });

  /// Restores progress from a backup. With [merge] the better score wins
  /// per question, matching how repeated answers are scored; otherwise the
  /// given scores replace all progress. Entries for questions missing from
  /// the catalog, or with an unexpected value, are dropped.
  Future<void> restoreProgress(Map<String, int> scores, {bool merge = false}) =>
      _enqueueWrite(() async {
        final known = _catalog?.knownQuestionIds;
        final incoming = {
          for (final entry in scores.entries)
            if ((known == null || known.contains(entry.key)) &&
                (entry.value == 5 || entry.value == 10))
              entry.key: entry.value,
        };
        final updated = merge ? mergeScores(_scores, incoming) : incoming;
        await _repository.save(updated);
        _scores = updated;
        _error = null;
        notifyListeners();
      });

  Future<bool> record(
    InterviewQuestion question, {
    required bool knewAnswer,
  }) async {
    if (_saving) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      return await _enqueueWrite(() async {
        final score = knewAnswer ? 10 : 5;
        final known = _catalog?.knownQuestionIds;
        if (known != null && !known.contains(question.id)) {
          _error = TrainingError.answerSave;
          return false;
        }
        final updated = {
          for (final entry in _scores.entries)
            if (known == null || known.contains(entry.key))
              entry.key: entry.value,
          question.id: score > (_scores[question.id] ?? 0)
              ? score
              : _scores[question.id]!,
        };
        await _repository.save(updated);
        _scores = updated;
        return true;
      });
    } catch (_) {
      _error = TrainingError.answerSave;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
