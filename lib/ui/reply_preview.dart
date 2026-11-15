import '../data/topic_draft.dart';

/// Возвращает читаемое markdown-представление ответа модели вместо сырого JSON.
///
/// Markdown появляется, только если весь [text] — это один JSON-объект
/// (черновик темы или обновление ответа), возможно обёрнутый в fenced-блок.
/// Обычные текстовые ответы, а также проза с фрагментами JSON, возвращают
/// `null`: их показывают как есть.
String? replyPreviewMarkdown(String text) {
  var candidate = text.trim();
  final fenced = RegExp(
    r'^```(?:json)?\s*(.*)\s*```$',
    dotAll: true,
    caseSensitive: false,
  ).firstMatch(candidate);
  if (fenced != null) candidate = fenced.group(1)!.trim();
  if (!candidate.startsWith('{') || !candidate.endsWith('}')) return null;
  final draft = parseTopicDraft(candidate);
  if (draft != null) return topicDraftPreviewMarkdown(draft);
  final update = parseAnswerUpdate(candidate);
  if (update != null) return answerUpdatePreviewMarkdown(update);
  return null;
}

/// Форматирует [TopicDraft] в markdown: заголовок темы, описание и нумерованный
/// список вопросов с эталонными ответами.
String topicDraftPreviewMarkdown(TopicDraft draft) {
  final buffer = StringBuffer();
  final title = draft.title;
  if (title != null && title.isNotEmpty) buffer.writeln('### $title');
  final description = draft.description;
  if (description != null && description.isNotEmpty) {
    buffer
      ..writeln(description)
      ..writeln();
  }
  for (var i = 0; i < draft.questions.length; i++) {
    final (prompt, answer) = draft.questions[i];
    buffer
      ..writeln('**${i + 1}. $prompt**')
      ..writeln()
      ..writeln(answer);
    if (i != draft.questions.length - 1) buffer.writeln();
  }
  return buffer.toString().trim();
}

/// Форматирует [AnswerUpdate] в markdown: вопрос и предложенный новый ответ.
String answerUpdatePreviewMarkdown(AnswerUpdate update) =>
    '**${update.prompt}**\n\n${update.answer}';
