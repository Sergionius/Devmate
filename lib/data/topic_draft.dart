import 'dart:convert';

/// Черновик, сгенерированный моделью в чате. В режиме создания темы
/// [title]/[description] заполнены; в режиме добавления вопросов в
/// существующую тему модель возвращает только [questions].
class TopicDraft {
  const TopicDraft(this.title, this.description, this.questions);

  final String? title;
  final String? description;
  final List<(String prompt, String answer)> questions;
}

/// Вытаскивает JSON-блок темы из ответа модели: голый объект или
/// ```json-фенс. Возвращает null, если валидной темы в тексте нет —
/// тогда ответ считается обычным сообщением (например, уточнением).
TopicDraft? parseTopicDraft(String text) {
  for (final candidate in _jsonCandidates(text)) {
    final draft = _decode(candidate);
    if (draft != null) return draft;
  }
  return null;
}

/// Правка ответа существующего вопроса: JSON с action=update_answer,
/// поля prompt (уточнённый вопрос) и answer (новый эталонный ответ).
class AnswerUpdate {
  const AnswerUpdate(this.prompt, this.answer);

  final String prompt;
  final String answer;
}

/// Вытаскивает из ответа модели команду замены ответа вопроса.
/// Возвращает null, если команды в тексте нет.
AnswerUpdate? parseAnswerUpdate(String text) {
  for (final candidate in _jsonCandidates(text)) {
    final Object? decoded;
    try {
      decoded = jsonDecode(candidate);
    } on FormatException {
      continue;
    }
    if (decoded is! Map<String, dynamic>) continue;
    if (decoded['action'] != 'update_answer') continue;
    final prompt = decoded['prompt'];
    final answer = decoded['answer'];
    if (prompt is! String ||
        prompt.trim().isEmpty ||
        answer is! String ||
        answer.trim().isEmpty) {
      continue;
    }
    return AnswerUpdate(prompt.trim(), answer.trim());
  }
  return null;
}

List<String> _jsonCandidates(String text) {
  final candidates = <String>[];
  final fenced = RegExp(
    r'```(?:json)?\s*(\{.*?\})\s*```',
    dotAll: true,
  ).firstMatch(text);
  if (fenced != null) candidates.add(fenced.group(1)!);
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start >= 0 && end > start) candidates.add(text.substring(start, end + 1));
  return candidates;
}

TopicDraft? _decode(String raw) {
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    // Ответ модели с «{» не обязан быть валидным JSON (уточнение, пример
    // кода, обрезанный ответ) — это обычный текст, а не черновик темы.
    return null;
  }
  if (decoded is! Map<String, dynamic>) return null;
  final questions = decoded['questions'];
  if (questions is! List || questions.isEmpty) return null;
  final parsed = <(String, String)>[];
  for (final question in questions) {
    if (question is! Map<String, dynamic>) return null;
    final prompt = question['prompt'];
    final answer = question['answer'];
    if (prompt is! String ||
        prompt.trim().isEmpty ||
        answer is! String ||
        answer.trim().isEmpty) {
      return null;
    }
    parsed.add((prompt.trim(), answer.trim()));
  }
  final title = decoded['title'];
  final description = decoded['description'];
  return TopicDraft(
    title is String && title.trim().isNotEmpty ? title.trim() : null,
    description is String ? description.trim() : null,
    parsed,
  );
}
