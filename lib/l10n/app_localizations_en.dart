// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatNew => 'New chat';

  @override
  String get chatHistoryEmpty =>
      'No conversations yet. Start a new chat to save your conversation.';

  @override
  String get chatHistoryReadError => 'Could not load chat history';

  @override
  String get chatHistorySaveError => 'Could not save this conversation';

  @override
  String get chatDeleteTitle => 'Delete conversation';

  @override
  String get chatDeleteWarning =>
      'This conversation and all its messages will be permanently deleted.';

  @override
  String get backupIncludeChats => 'Include general chat history';

  @override
  String backupChatsInFile(int count) {
    return 'Conversations in file: $count. Replacing this backup will delete your current chat history and replace it with these conversations.';
  }

  @override
  String get chatHistoryWriteError => 'Could not update chat history';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatShare => 'Share';

  @override
  String get vacancyTitle => 'Questions from a job posting';

  @override
  String get vacancyCardSubtitle =>
      'Turn a job description into interview questions with AI';

  @override
  String get vacancyIntro =>
      'Paste the job description below. You can review and edit each question before saving. The text will be sent to your AI provider.';

  @override
  String get vacancyText => 'Job description';

  @override
  String get vacancyHint => 'Requirements, responsibilities, tech stack…';

  @override
  String get vacancyGenerate => 'Generate questions';

  @override
  String get vacancyGenerating => 'Generating questions…';

  @override
  String get vacancyPreview => 'Review questions';

  @override
  String get vacancyDestination => 'Save to';

  @override
  String get vacancyNewTopic => 'New topic';

  @override
  String get vacancyTopicTitle => 'Topic title';

  @override
  String get vacancyTopicDescription => 'Topic description';

  @override
  String get vacancyQuestion => 'Question';

  @override
  String get vacancyAnswer => 'Reference answer';

  @override
  String get vacancyEdit => 'Edit question';

  @override
  String get vacancyApply => 'Done';

  @override
  String get vacancyRemove => 'Remove question';

  @override
  String get vacancySave => 'Save questions to topic';

  @override
  String get vacancyValidate =>
      'Enter a topic title and keep at least one complete question.';

  @override
  String get vacancyNoQuestions =>
      'All questions were removed. Generate a new set before saving.';

  @override
  String get vacancyAiDisabled =>
      'AI is disabled in Settings. Job posting import is unavailable.';

  @override
  String get vacancyEnterText => 'Paste a job description first.';

  @override
  String get vacancyReplaceTitle => 'Replace the current preview?';

  @override
  String get vacancyReplaceWarning =>
      'The current questions and your edits will be lost. Generate a new set?';

  @override
  String get vacancyReplaceAction => 'Generate again';

  @override
  String get vacancyKeyRequired =>
      'Add an API key in AI settings to generate questions from a job posting.';

  @override
  String get vacancyGenerationError =>
      'Couldn\'t generate questions. Check your connection and try again.';

  @override
  String get vacancyInvalidReply =>
      'The AI response didn\'t include a valid list of questions. Try generating again.';

  @override
  String get vacancySaveError =>
      'Couldn\'t save the questions. Check the destination and try again.';

  @override
  String get vacancyInstruction =>
      'Create technical interview practice questions based on the job description. Write in English. Focus on requirements and technologies actually mentioned; do not invent unrelated requirements. Return exactly one JSON object, without Markdown or commentary: title (a short topic title), description (a brief summary), and questions (an array of 4–10 objects, each with a non-empty prompt and answer). Each reference answer should be accurate and 2–4 sentences long. Avoid duplicate questions. If the description is vague, cover only the requirements it explicitly states.';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchHint => 'Search topics and questions';

  @override
  String get searchClear => 'Clear search';

  @override
  String get searchAnswers => 'Include answers';

  @override
  String get searchStart => 'Enter a word or phrase to search the library.';

  @override
  String get searchEmpty => 'No matches found.';

  @override
  String get searchTopics => 'Topics';

  @override
  String get searchQuestions => 'Questions';

  @override
  String get questionsManagement => 'Question management';

  @override
  String get questionsJsonHint =>
      'Export copies questions JSON to the clipboard. Import offers two modes: \'Replace all\' swaps every topic and question for the pasted JSON and resets progress; \'Add\' appends questions into topics with matching titles, creates missing topics and keeps the existing catalog and progress.';

  @override
  String get exportQuestions => 'Copy questions as JSON';

  @override
  String get importQuestions => 'Import JSON';

  @override
  String get pasteQuestionsJson => 'Paste JSON with topics and questions';

  @override
  String get questionsCopied => 'Questions JSON copied to the clipboard';

  @override
  String get importAppendAction => 'Add';

  @override
  String get importReplaceAction => 'Replace all';

  @override
  String get questionsImported => 'Catalog replaced from JSON, progress reset';

  @override
  String get questionsAppended =>
      'Questions added; existing topics and progress are kept';

  @override
  String get importFailed => 'Failed to import questions';

  @override
  String get resetTopicProgress => 'Reset topic progress';

  @override
  String resetTopicProgressWarning(String title) {
    return 'Delete training results for \"$title\" only?';
  }

  @override
  String get resetTopicProgressDone => 'Topic progress reset';

  @override
  String get resetProgress => 'Reset progress only';

  @override
  String get resetProgressWarning =>
      'Delete all training results and points? Questions, topics and AI settings will be kept. This action cannot be undone.';

  @override
  String get resetProgressDone => 'Progress reset';

  @override
  String get resetProgressFailed => 'Failed to reset progress';

  @override
  String get resetAll => 'Reset everything';

  @override
  String get resetWarning =>
      'Delete user topics, questions, edits, progress and AI settings? Built-in questions will return to their original state. This action cannot be undone.';

  @override
  String get resetDone => 'Original state restored';

  @override
  String get resetFailed => 'Failed to complete the reset';

  @override
  String get cancelAction => 'Cancel';

  @override
  String get agentJsonInstruction =>
      'Agent instruction: create valid JSON without Markdown. The root object must have version set to 1 and a non-empty topics array. Each topic has a non-empty title, a string description (may be empty) and a non-empty questions array. Every question has non-empty prompt and answer. For each topic prepare 4–12 distinct questions; answers should be precise, 2–4 sentences each. Don\'t include IDs — the app will generate them on import.';

  @override
  String get shareInstruction => 'Share instruction';

  @override
  String get shareFailed => 'Couldn\'t open the share menu';

  @override
  String get exportQuestionsFile => 'Export to file';

  @override
  String get importQuestionsFile => 'Import from file';

  @override
  String get fileReadFailed => 'Couldn\'t read the file';

  @override
  String get backupSectionTitle => 'Full backup';

  @override
  String get backupHint =>
      'A single JSON file with your topics, progress, and settings — handy when moving to another device. API keys are never included. Replace everything restores exactly what the file contains. Merge adds topics on top of your current ones: questions that already exist on this device keep their best score, while progress for newly added topics starts fresh. Settings are left untouched.';

  @override
  String get exportBackup => 'Export everything';

  @override
  String get importBackup => 'Import backup';

  @override
  String backupSummary(int topics, int answers) {
    return 'Topics in file: $topics, questions with progress marks: $answers';
  }

  @override
  String get backupMergeAction => 'Merge';

  @override
  String get backupReplaceAction => 'Replace everything';

  @override
  String get backupImportedReplace => 'Backup restored';

  @override
  String get backupImportedMerge =>
      'Topics added. Existing questions keep their best score; progress for newly added topics starts fresh';

  @override
  String get backupInvalid => 'Not a Devmate backup file';

  @override
  String get backupImportFailed => 'Failed to restore the backup';

  @override
  String get pageNotFound => 'This page does not exist.';

  @override
  String get goHome => 'Home';

  @override
  String get aiSettings => 'AI settings';

  @override
  String get logoSemantics => 'Devmate logo';

  @override
  String get homeEyebrow => 'TECH INTERVIEW PREP';

  @override
  String get homeTitle => 'Sharpen your answer.\nDon\'t guess.';

  @override
  String get homeSubtitle =>
      'Work through questions, compare with the reference and revisit the hard ones.';

  @override
  String get continueTraining => 'Continue training';

  @override
  String get retry => 'Retry';

  @override
  String get libraryEyebrow => 'LIBRARY / 10 TRACKS';

  @override
  String get chooseTopic => 'Pick a topic';

  @override
  String get statsEyebrow => 'YOUR STATS';

  @override
  String get statsCompletedLabel => 'questions completed';

  @override
  String totalQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count questions',
      one: '$count question',
    );
    return '$_temp0';
  }

  @override
  String get topicEyebrowDirection => 'Track';

  @override
  String get topicEyebrow => 'LIBRARY / TOPIC';

  @override
  String get repeatTopic => 'Repeat topic';

  @override
  String get discussTopicWithAi => 'Discuss with AI';

  @override
  String get questionsEyebrow => 'QUESTIONS';

  @override
  String get knownXp => 'Know it · 10 XP';

  @override
  String get repeatedXp => 'Reviewed · 5 XP';

  @override
  String topicProgress(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total questions',
      one: '$total question',
    );
    return '$completed of $_temp0 done';
  }

  @override
  String get practiceSaveFailed => 'Failed to save the answer';

  @override
  String get stepYourAnswer => '01 / YOUR ANSWER';

  @override
  String get yourAnswerHint =>
      'Put it in your own words. There is no automatic grading — try to recall it yourself first.';

  @override
  String get yourAnswerLabel => 'Your answer';

  @override
  String get answerPlaceholder => 'Start writing here...';

  @override
  String get compareWithReference => 'Compare with reference';

  @override
  String get discussWithAi => 'Work through it with AI';

  @override
  String get stepComparison => '02 / COMPARISON';

  @override
  String get yourAnswerEyebrow => 'YOUR ANSWER';

  @override
  String get referenceAnswerEyebrow => 'REFERENCE ANSWER';

  @override
  String get howCloseQuestion => 'How close were you?';

  @override
  String get knewAnswerXp => 'Knew it · +10 XP';

  @override
  String get needsRepeat => 'Needs review';

  @override
  String get stepConsolidation => '03 / CONSOLIDATION';

  @override
  String get consolidationHint =>
      'Recall the reference answer and write it again in your own words. We do not compare wording automatically.';

  @override
  String get whatToRemember => 'What\'s worth remembering?';

  @override
  String get writeEssencePlaceholder => 'Write down the essence...';

  @override
  String get consolidateXp => 'Consolidate · +5 XP';

  @override
  String get viewReferenceAgain => 'See the reference again';

  @override
  String get doneTitle => 'Great. That answer counts.';

  @override
  String get doneSubtitle => 'The hard parts start to click.';

  @override
  String get progressSavedNote => 'Progress is saved on this device.';

  @override
  String get backToTopic => 'Back to topic';

  @override
  String get nextQuestion => 'Next question';

  @override
  String questionProgress(int current, int total) {
    return 'QUESTION $current / $total';
  }

  @override
  String get progressLoadError => 'Failed to load progress. Try again.';

  @override
  String get answerSaveError => 'Failed to save the answer. Try again.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAiTitle => 'AI provider (BYOK)';

  @override
  String get settingsDisableAi => 'Disable AI';

  @override
  String get settingsAiSection => 'AI provider';

  @override
  String get settingsAiSectionNote => 'Provider, model and API key';

  @override
  String get settingsDataTitle => 'Questions and data';

  @override
  String get settingsDataSectionNote => 'Import, export and reset';

  @override
  String get settingsEyebrow => 'ANY OPENAI-COMPATIBLE ENDPOINT';

  @override
  String get settingsLanguage => 'App language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageRestartNote =>
      'The interface switches immediately; questions use the new language after restarting the app.';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeSystem => 'Match device';

  @override
  String get keyPrivacyNote =>
      'The key is stored only on this device and is sent directly to the chosen provider.';

  @override
  String get webCorsNote =>
      'On the web, only CORS-enabled providers work: OpenAI, OpenRouter, Groq. z.ai and DeepSeek block browser requests — use the app on iOS/Android or pick another provider.';

  @override
  String get worksInBrowserSuffix => '· works in the browser';

  @override
  String get providerLabel => 'Provider';

  @override
  String get baseUrlLabel => 'Base URL';

  @override
  String get baseUrlHint => 'https://api.z.ai/api/paas/v4';

  @override
  String get modelLabel => 'Model';

  @override
  String get modelHint => 'glm-5.3-flash';

  @override
  String get apiKeyLabel => 'API key';

  @override
  String get apiKeyHint => 'Enter your key';

  @override
  String get saving => 'Saving...';

  @override
  String get save => 'Save';

  @override
  String get testing => 'Testing...';

  @override
  String get testConnection => 'Test connection';

  @override
  String get settingsLoadError =>
      'Failed to read settings. Check storage availability.';

  @override
  String get settingsSaved => 'Settings saved on this device.';

  @override
  String get settingsSaveError => 'Failed to save settings on this device.';

  @override
  String get fillAllFields => 'Fill in the URL, model and API key.';

  @override
  String get connectionOk => 'Connection works ✓';

  @override
  String get chatKeyRequired => 'API key required';

  @override
  String get chatKeyRequiredDescription =>
      'The AI chat works with your key from an OpenAI-compatible provider. Add it in settings — it stays on this device.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get chatEyebrow => 'ASK AWAY — ANSWERS STREAM IN';

  @override
  String get topicChatIntro =>
      'I\'ll prep you for the interview: explaining, guiding, and checking as we go.';

  @override
  String get questionChatIntro =>
      'Write your answer or ask a question about it.';

  @override
  String get chatInputHint => 'Ask anything…';

  @override
  String chatSettingsReadError(String error) {
    return 'Failed to read settings: $error';
  }

  @override
  String get llmKeyRejected =>
      'Key rejected (401). Check the API key in settings.';

  @override
  String get llmNotFound =>
      'Address or model not found (404). Check the base URL and model name.';

  @override
  String get llmRateLimited =>
      'Too many requests (429). Wait or check your quota.';

  @override
  String get llmNoBalance =>
      'The provider account has no funds or plan. Top up your balance or pick another provider.';

  @override
  String get llmWebConnectionError =>
      'Could not connect to the provider. On the web, only CORS-enabled providers work (OpenAI, OpenRouter, Groq). Check settings and internet.';

  @override
  String get llmConnectionError =>
      'Could not connect to the provider. Check settings and internet.';

  @override
  String get llmTestEmptyResponse =>
      'The provider replied with an empty message.';

  @override
  String get llmEmptyReply => 'The provider returned an empty reply.';

  @override
  String llmProviderDetail(String detail) {
    return 'Provider reply: $detail';
  }

  @override
  String topicChatTitle(String title) {
    return 'AI · $title';
  }

  @override
  String questionChatTitle(int index) {
    return 'AI · Question $index';
  }

  @override
  String topicSystemPrompt(String title, String description) {
    return 'You are a technical interviewer preparing the user for a job interview on the topic \"$title\" ($description). Answer in English, briefly and to the point: explain with examples, ask leading questions, check understanding. Don\'t solve for the user until they\'ve tried it themselves.';
  }

  @override
  String questionSystemPrompt(String prompt, String reference) {
    return 'You\'re working through a question with the user: \"$prompt\". Your reference answer is: \"$reference\". Answer in English: do not reveal the whole reference at once — use leading questions and examples to help the user formulate the answer themselves, then compare with the reference and point out what to add. If the user asks to fix, extend or record the correct answer — reply with exactly one JSON object and no explanations: the field action with the value update_answer, the field prompt with the refined question text, the field answer with the new reference answer.';
  }

  @override
  String questionDraftPart(String draft) {
    return 'The user\'s answer draft: \"$draft\". ';
  }

  @override
  String get topicSuggestionStart => 'Where should I start with this topic?';

  @override
  String get topicSuggestionQuiz => 'Ask me 3 typical interview questions';

  @override
  String get topicSuggestionExplainer =>
      'Break down one concept in plain words, with an example';

  @override
  String get editTopicButton => 'Edit';

  @override
  String get editTopicTitle => 'Edit topic';

  @override
  String get editTopicNameLabel => 'Title';

  @override
  String get addTopicTitleRequired => 'Enter a topic title.';

  @override
  String get editTopicDescLabel => 'Description';

  @override
  String get editSaveTopic => 'Save topic';

  @override
  String get editAddQuestion => 'Add question';

  @override
  String get editQuestionDialogTitleNew => 'New question';

  @override
  String get editQuestionDialogTitleEdit => 'Edit question';

  @override
  String get editPromptLabel => 'Question';

  @override
  String get editAnswerLabel => 'Reference answer';

  @override
  String get editSave => 'Save';

  @override
  String get editDeleteQuestion => 'Delete';

  @override
  String get editRequired => 'Fill in the question and the answer.';

  @override
  String get editSaved => 'Saved';

  @override
  String get answerUpdateCardTitle => 'The model suggests a revised answer';

  @override
  String get answerUpdatePromptLabel => 'Refined question';

  @override
  String get answerUpdateButton => 'Replace answer';

  @override
  String get answerReplaced => 'Answer updated in the topic';

  @override
  String get freeChatTitle => 'General chat';

  @override
  String get freeChatCardSubtitle =>
      'Any topic: career, learning, hobbies — whatever\'s on your mind.';

  @override
  String get freeChatIntro =>
      'Let\'s chat about anything: work, study, hobbies or just thoughts out loud.';

  @override
  String get freeSystemPrompt =>
      'You are a friendly conversation partner for free-form chat on any topics. Answer in English: lively, curious and without moralizing; keep the conversation going, ask follow-up questions, share examples. If the topic is technical — go into details; if it is light — stay light.';

  @override
  String get freeSuggestionIcebreaker =>
      'Suggest a topic and ask the first question';

  @override
  String get freeSuggestionCareer =>
      'Let\'s discuss how to deal with burnout at work';

  @override
  String get freeSuggestionFun => 'Tell me a surprising fact about space';

  @override
  String get createChatTitle => 'Create topic';

  @override
  String get createChatCardSubtitle =>
      'Describe a topic and its questions — I\'ll put it together for you.';

  @override
  String get createChatIntro =>
      'Describe the topic you want: name, level and number of questions. If anything is unclear — I will ask.';

  @override
  String get createSystemPrompt =>
      'You help the user create training topics for interview preparation. Answer in English. Rules: (1) If the request is clear — reply with exactly one JSON object with no markdown wrappers or explanations. The object schema: field title — string, topic name; field description — string, one sentence about the topic; field questions — array of objects where each object has field prompt (question) and field answer (reference answer in 2-4 sentences). From 4 to 12 questions, questions and answers in English. (2) If something is missing for a good topic (level, stack, depth) — ask one short clarifying question in plain text, without JSON. (3) Any extra text next to the JSON is forbidden.';

  @override
  String get createSuggestionDocker =>
      'Build a topic \"Docker for beginners\" — 5 questions';

  @override
  String get createSuggestionTypescript =>
      '10 TypeScript questions for a mid-level developer';

  @override
  String get createSuggestionSql =>
      'SQL topic: queries and indexes, 6 questions';

  @override
  String get createAddTopic => 'Add topic';

  @override
  String get createSaveError => 'Failed to save the topic. Try again.';

  @override
  String get createAddTopicSuccess =>
      'Topic added — you\'ll find it in the library on the home screen';

  @override
  String get appendChatButton => 'Add questions with AI';

  @override
  String appendChatTitle(String title) {
    return 'Questions · $title';
  }

  @override
  String get appendChatIntro =>
      'Tell me which questions to add to the topic. I will ask if anything is unclear.';

  @override
  String appendSystemPrompt(String title, String existing) {
    return 'You add questions to the existing training topic \"$title\". Answer in English. Existing questions in this topic: $existing. Rules: (1) If the request is clear — reply with exactly one JSON object with no markdown wrappers or explanations: a single field questions — array of objects where each object has field prompt (new question) and field answer (reference answer in 2-4 sentences). From 3 to 10 questions, in English, they must not repeat the listed questions. (2) If the request is ambiguous — ask one short clarifying question in plain text, without JSON. (3) Any extra text next to the JSON is forbidden.';
  }

  @override
  String appendSuggestionBasics(String title) {
    return 'Add junior-level basics on \"$title\"';
  }

  @override
  String appendSuggestionPractice(String title) {
    return 'Add 3 hands-on exercises on \"$title\"';
  }

  @override
  String get appendSuggestionEdgeCases =>
      'Add questions about typical mistakes and pitfalls';

  @override
  String appendAddTopic(String title) {
    return 'Add to topic \"$title\"';
  }

  @override
  String appendAddedSuccess(String title) {
    return 'Questions added to topic \"$title\"';
  }

  @override
  String createAddedQuestionsSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'questions',
      one: 'question',
    );
    return '$_temp0';
  }

  @override
  String get presetZaiCodingLabel => 'z.ai GLM Coding (subscription)';

  @override
  String get presetZaiLabel => 'z.ai API (pay-as-you-go)';

  @override
  String get presetOllamaLabel => 'Ollama (local)';

  @override
  String get presetCustomLabel => 'Custom endpoint';
}
