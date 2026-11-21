import '../domain/question.dart';

class QuestionSearchHit {
  const QuestionSearchHit(this.topic, this.question, this.index, this.inAnswer);

  final InterviewTopic topic;
  final InterviewQuestion question;
  final int index;
  final bool inAnswer;
}

class CatalogSearchResults {
  const CatalogSearchResults(this.topics, this.questions);

  final List<InterviewTopic> topics;
  final List<QuestionSearchHit> questions;
}

CatalogSearchResults searchCatalog(
  Iterable<InterviewTopic> catalog,
  String query, {
  bool includeAnswers = false,
}) {
  final terms = query.trim().toLowerCase().split(RegExp(r'\s+'));
  if (terms.length == 1 && terms.single.isEmpty) {
    return const CatalogSearchResults([], []);
  }

  bool matches(String value) {
    final text = value.toLowerCase();
    return terms.every(text.contains);
  }

  final topics = <InterviewTopic>[];
  final questions = <QuestionSearchHit>[];
  for (final topic in catalog) {
    if (matches(topic.title) || matches(topic.description)) topics.add(topic);
    for (var index = 0; index < topic.questions.length; index++) {
      final question = topic.questions[index];
      final inPrompt = matches(question.prompt);
      final inAnswer = includeAnswers && matches(question.answer);
      if (inPrompt || inAnswer) {
        questions.add(
          QuestionSearchHit(topic, question, index, !inPrompt && inAnswer),
        );
      }
    }
  }
  return CatalogSearchResults(topics, questions);
}
