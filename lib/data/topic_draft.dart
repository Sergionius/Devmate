import 'dart:convert';

class TopicDraft {
  const TopicDraft(this.title, this.description, this.questions);

  final String? title;
  final String? description;
  final List<(String prompt, String answer)> questions;
}

TopicDraft? parseTopicDraft(String text) {
  for (final candidate in _jsonCandidates(text)) {
    final draft = _decode(candidate);
    if (draft != null) return draft;
  }
  return null;
}

class AnswerUpdate {
  const AnswerUpdate(this.prompt, this.answer);

  final String prompt;
  final String answer;
}

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
