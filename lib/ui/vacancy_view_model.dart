import 'package:flutter/foundation.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../data/topic_draft.dart';

enum VacancyPhase { idle, generating, preview, saving }

enum VacancyFailure { notConfigured, generation, invalidReply, save }

class VacancyViewModel extends ChangeNotifier {
  VacancyViewModel({
    required this.settings,
    required this.catalog,
    ChatSession Function(LlmSettings settings, String prompt)? sessionFactory,
  }) : _sessionFactory =
           sessionFactory ??
           ((settings, prompt) => OpenAiCompatibleProvider(
             settings: settings,
             systemPrompt: prompt,
           ));

  final LlmSettingsRepository settings;
  final TopicCatalog catalog;
  final ChatSession Function(LlmSettings, String) _sessionFactory;
  VacancyPhase phase = VacancyPhase.idle;
  TopicDraft? draft;
  List<(String prompt, String answer)> questions = [];
  VacancyFailure? error;
  bool _disposed = false;
  int _generation = 0;
  ChatSession? _activeSession;

  void cancelGeneration() {
    _generation++;
    _activeSession?.dispose();
    _activeSession = null;
    if (phase == VacancyPhase.generating) phase = VacancyPhase.idle;
    if (phase != VacancyPhase.preview && phase != VacancyPhase.saving) {
      draft = null;
      questions = [];
    }
    error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> generate(String text, String instruction) async {
    if (phase == VacancyPhase.generating ||
        phase == VacancyPhase.saving ||
        text.trim().isEmpty) {
      return;
    }
    final generation = ++_generation;
    phase = VacancyPhase.generating;
    error = null;
    draft = null;
    questions = [];
    _notify();
    ChatSession? session;
    try {
      final config = await settings.load();
      if (!config.isConfigured) throw VacancyFailure.notConfigured;
      if (_disposed || generation != _generation) return;
      session = _sessionFactory(config, instruction);
      _activeSession = session;
      await for (final _ in session.sendMessageStream(text.trim())) {}
      if (_disposed || generation != _generation) return;
      final messages = session.history;
      if (messages.isEmpty || messages.last.failed) {
        throw VacancyFailure.generation;
      }
      final parsed = parseTopicDraft(messages.last.text);
      if (parsed == null) throw VacancyFailure.invalidReply;
      draft = parsed;
      questions = [...parsed.questions];
      phase = VacancyPhase.preview;
    } catch (e) {
      if (!_disposed && generation == _generation) {
        debugPrint('VacancyViewModel: generation failed: $e');
        error = e is VacancyFailure ? e : VacancyFailure.generation;
        phase = VacancyPhase.idle;
      }
    } finally {
      if (identical(session, _activeSession)) {
        session?.dispose();
        _activeSession = null;
      }
      if (generation == _generation) _notify();
    }
  }

  void removeQuestion(int index) {
    if (phase != VacancyPhase.preview) return;
    questions.removeAt(index);
    _notify();
  }

  void updateQuestion(int index, String prompt, String answer) {
    if (phase != VacancyPhase.preview) return;
    questions[index] = (prompt.trim(), answer.trim());
    _notify();
  }

  Future<bool> save({
    String? topicId,
    String? title,
    String description = '',
  }) async {
    if (phase != VacancyPhase.preview ||
        questions.isEmpty ||
        questions.any((q) => q.$1.isEmpty || q.$2.isEmpty) ||
        (topicId == null && (title?.trim().isEmpty ?? true))) {
      return false;
    }
    phase = VacancyPhase.saving;
    error = null;
    _notify();
    try {
      if (topicId != null) {
        await catalog.addQuestionsToTopic(topicId, questions);
      } else {
        await catalog.addUserTopic(
          title!.trim(),
          description.trim(),
          questions,
        );
      }
      if (!_disposed) {
        draft = null;
        questions = [];
        phase = VacancyPhase.idle;
        _notify();
      }
      return true;
    } catch (e) {
      if (!_disposed) {
        debugPrint('VacancyViewModel: save failed: $e');
        error = VacancyFailure.save;
        phase = VacancyPhase.preview;
        _notify();
      }
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _activeSession?.dispose();
    _activeSession = null;
    super.dispose();
  }
}
