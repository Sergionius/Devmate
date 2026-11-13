class InterviewQuestion {
  const InterviewQuestion(this.id, this.prompt, this.answer);

  final String id;
  final String prompt;
  final String answer;
}

class InterviewTopic {
  const InterviewTopic(this.id, this.title, this.description, this.questions);

  final String id;
  final String title;
  final String description;
  final List<InterviewQuestion> questions;
}
