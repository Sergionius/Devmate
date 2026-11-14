import 'package:flutter/foundation.dart';

import '../data/progress_repository.dart';
import '../domain/question.dart';

/// Ошибки тренировки; текст локализуется в UI.
enum TrainingError { progressLoad, answerSave }

class TrainingViewModel extends ChangeNotifier {
  TrainingViewModel(this._repository);

  final ProgressRepository _repository;
  Map<String, int> _scores = {};
  bool _loading = true;
  bool _saving = false;
  TrainingError? _error;

  bool get loading => _loading;
  bool get saving => _saving;
  TrainingError? get error => _error;
  int get points => _scores.values.fold(0, (sum, value) => sum + value);
  int get completed => _scores.length;
  int completedIn(InterviewTopic topic) => topic.questions
      .where((question) => _scores.containsKey(question.id))
      .length;
  int? scoreFor(InterviewQuestion question) => _scores[question.id];

  Future<void> load() async {
    try {
      _scores = await _repository.load();
      _error = null;
    } catch (_) {
      _error = TrainingError.progressLoad;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> record(
    InterviewQuestion question, {
    required bool knewAnswer,
  }) async {
    if (_saving) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final score = knewAnswer ? 10 : 5;
      final updated = {
        ..._scores,
        question.id: score > (_scores[question.id] ?? 0)
            ? score
            : _scores[question.id]!,
      };
      await _repository.save(updated);
      _scores = updated;
      return true;
    } catch (_) {
      _error = TrainingError.answerSave;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
