// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get questionsManagement => 'Управление вопросами';

  @override
  String get questionsJsonHint =>
      'Экспорт копирует JSON в буфер обмена. Импорт предлагает два режима: «Заменить всё» заменяет все темы и вопросы из вставленного JSON и сбрасывает прогресс; «Добавить» дописывает вопросы в темы с совпадающими названиями, создаёт отсутствующие темы и сохраняет существующий каталог и прогресс.';

  @override
  String get exportQuestions => 'Скопировать вопросы в JSON';

  @override
  String get importQuestions => 'Импортировать JSON';

  @override
  String get pasteQuestionsJson => 'Вставьте JSON с темами и вопросами';

  @override
  String get questionsCopied => 'JSON вопросов скопирован в буфер обмена';

  @override
  String get importAppendAction => 'Добавить';

  @override
  String get importReplaceAction => 'Заменить всё';

  @override
  String get questionsImported => 'Каталог заменён из JSON, прогресс сброшен';

  @override
  String get questionsAppended =>
      'Вопросы добавлены, существующие темы и прогресс сохранены';

  @override
  String get importFailed => 'Не удалось импортировать вопросы';

  @override
  String get resetTopicProgress => 'Сбросить прогресс раздела';

  @override
  String resetTopicProgressWarning(String title) {
    return 'Удалить результаты тренировок только в разделе «$title»? Прогресс других разделов, вопросы и настройки сохранятся.';
  }

  @override
  String get resetTopicProgressDone => 'Прогресс раздела сброшен';

  @override
  String get resetProgress => 'Сбросить только прогресс';

  @override
  String get resetProgressWarning =>
      'Удалить все результаты тренировок и очки? Вопросы, темы и настройки AI сохранятся. Это действие нельзя отменить.';

  @override
  String get resetProgressDone => 'Прогресс сброшен';

  @override
  String get resetProgressFailed => 'Не удалось сбросить прогресс';

  @override
  String get resetAll => 'Сбросить всё';

  @override
  String get resetWarning =>
      'Удалить пользовательские темы, вопросы, изменения, прогресс и настройки AI? Встроенные вопросы вернутся к исходному состоянию. Это действие нельзя отменить.';

  @override
  String get resetDone => 'Исходное состояние восстановлено';

  @override
  String get resetFailed => 'Не удалось завершить сброс';

  @override
  String get cancelAction => 'Отмена';

  @override
  String get agentJsonInstruction =>
      'Инструкция для агента: создай валидный JSON без Markdown. Корневой объект содержит version со значением 1 и topics — непустой массив тем. Каждая тема содержит непустой title, строковое description (можно пустое) и непустой массив questions. Каждый вопрос содержит непустые prompt и answer. Для каждой темы подготовь 4–12 неповторяющихся вопросов на русском; ответы — точные, по 2–4 предложения. ID не нужны — приложение создаст их при импорте.';

  @override
  String get shareInstruction => 'Поделиться инструкцией';

  @override
  String get shareFailed => 'Не удалось открыть меню «Поделиться»';

  @override
  String get pageNotFound => 'Такой страницы нет.';

  @override
  String get goHome => 'На главную';

  @override
  String get aiSettings => 'Настройки AI';

  @override
  String get offlineBadge => 'ОФЛАЙН';

  @override
  String get logoSemantics => 'Логотип Devmate';

  @override
  String get homeEyebrow => 'ПОДГОТОВКА К ТЕХНИЧЕСКОМУ ИНТЕРВЬЮ';

  @override
  String get homeTitle => 'Прокачай ответ.\nНе угадывай.';

  @override
  String get homeSubtitle =>
      'Разбирай вопросы, сверяйся с эталоном и возвращайся к сложному.';

  @override
  String get continueTraining => 'Продолжить тренировку';

  @override
  String get retry => 'Повторить';

  @override
  String get libraryEyebrow => 'БИБЛИОТЕКА / 10 НАПРАВЛЕНИЙ';

  @override
  String get chooseTopic => 'Выбери тему';

  @override
  String get statsEyebrow => 'ТВОЯ СТАТИСТИКА';

  @override
  String get statsCompletedLabel => 'вопросов пройдено';

  @override
  String totalQuestions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вопроса',
      many: '$count вопросов',
      few: '$count вопроса',
      one: '$count вопрос',
    );
    return '$_temp0';
  }

  @override
  String get topicEyebrowDirection => 'Направление';

  @override
  String get topicEyebrow => 'БИБЛИОТЕКА / ТЕМА';

  @override
  String get repeatTopic => 'Повторить тему';

  @override
  String get discussTopicWithAi => 'Обсудить тему с AI';

  @override
  String get questionsEyebrow => 'ВОПРОСЫ';

  @override
  String get knownXp => 'Знаю · 10 XP';

  @override
  String get repeatedXp => 'Повторил · 5 XP';

  @override
  String topicProgress(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total вопроса',
      many: '$total вопросов',
      few: '$total вопросов',
      one: '$total вопроса',
    );
    return '$completed из $_temp0 пройдено';
  }

  @override
  String get practiceSaveFailed => 'Не удалось сохранить ответ';

  @override
  String get stepYourAnswer => '01 / ТВОЙ ОТВЕТ';

  @override
  String get yourAnswerHint =>
      'Сформулируй своими словами. Здесь нет автоматической проверки — сначала попробуй вспомнить сам.';

  @override
  String get yourAnswerLabel => 'Твой ответ';

  @override
  String get answerPlaceholder => 'Начни писать здесь...';

  @override
  String get compareWithReference => 'Сверить с эталоном';

  @override
  String get discussWithAi => 'Разобрать с AI';

  @override
  String get stepComparison => '02 / СРАВНЕНИЕ';

  @override
  String get yourAnswerEyebrow => 'ТВОЙ ОТВЕТ';

  @override
  String get referenceAnswerEyebrow => 'ЭТАЛОННЫЙ ОТВЕТ';

  @override
  String get howCloseQuestion => 'Насколько близко получилось?';

  @override
  String get knewAnswerXp => 'Знал ответ · +10 XP';

  @override
  String get needsRepeat => 'Нужно повторить';

  @override
  String get stepConsolidation => '03 / ЗАКРЕПЛЕНИЕ';

  @override
  String get consolidationHint =>
      'Вспомни эталонный ответ и запиши его снова своими словами. Мы не сравниваем формулировки автоматически.';

  @override
  String get whatToRemember => 'Что важно запомнить?';

  @override
  String get writeEssencePlaceholder => 'Запиши суть ответа...';

  @override
  String get consolidateXp => 'Закрепить · +5 XP';

  @override
  String get viewReferenceAgain => 'Посмотреть эталон снова';

  @override
  String get doneTitle => 'Отлично. Ответ засчитан.';

  @override
  String get doneSubtitle => 'Сложное становится понятнее.';

  @override
  String get progressSavedNote => 'Прогресс сохранён на этом устройстве.';

  @override
  String get backToTopic => 'К теме';

  @override
  String get nextQuestion => 'Следующий вопрос';

  @override
  String questionProgress(int current, int total) {
    return 'ВОПРОС $current / $total';
  }

  @override
  String get progressLoadError =>
      'Не удалось загрузить прогресс. Попробуйте ещё раз.';

  @override
  String get answerSaveError =>
      'Не удалось сохранить ответ. Попробуйте ещё раз.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAiTitle => 'AI-провайдер (BYOK)';

  @override
  String get settingsDisableAi => 'Отключить AI';

  @override
  String get settingsAiSection => 'AI-провайдер';

  @override
  String get settingsAiSectionNote => 'Провайдер, модель и API-ключ';

  @override
  String get settingsDataTitle => 'Вопросы и данные';

  @override
  String get settingsDataSectionNote => 'Импорт, экспорт и сброс';

  @override
  String get settingsEyebrow => 'ЛЮБОЙ OPENAI-СОВМЕСТИМЫЙ ENDPOINT';

  @override
  String get settingsLanguage => 'Язык приложения';

  @override
  String get settingsLanguageSystem => 'Как в системе';

  @override
  String get settingsLanguageRestartNote =>
      'Интерфейс переключится сразу; вопросы будут на выбранном языке после перезапуска приложения.';

  @override
  String get settingsTheme => 'Оформление';

  @override
  String get settingsThemeDark => 'Тёмная';

  @override
  String get settingsThemeLight => 'Светлая';

  @override
  String get settingsThemeSystem => 'Как на устройстве';

  @override
  String get keyPrivacyNote =>
      'Ключ хранится только на этом устройстве и уходит напрямую выбранному провайдеру.';

  @override
  String get webCorsNote =>
      'На web работают только провайдеры с CORS: OpenAI, OpenRouter, Groq. z.ai и DeepSeek блокируют запросы из браузера — используйте приложение на iOS/Android или другой провайдер.';

  @override
  String get worksInBrowserSuffix => '· работает в браузере';

  @override
  String get providerLabel => 'Провайдер';

  @override
  String get baseUrlLabel => 'Base URL';

  @override
  String get baseUrlHint => 'https://api.z.ai/api/paas/v4';

  @override
  String get modelLabel => 'Модель';

  @override
  String get modelHint => 'glm-5.3-flash';

  @override
  String get apiKeyLabel => 'API-ключ';

  @override
  String get apiKeyHint => 'Введите ваш ключ';

  @override
  String get saving => 'Сохраняем...';

  @override
  String get save => 'Сохранить';

  @override
  String get testing => 'Проверяем...';

  @override
  String get testConnection => 'Проверить соединение';

  @override
  String get settingsLoadError =>
      'Не удалось прочитать настройки. Проверьте доступность хранилища.';

  @override
  String get settingsSaved => 'Настройки сохранены на этом устройстве.';

  @override
  String get settingsSaveError =>
      'Не удалось сохранить настройки на этом устройстве.';

  @override
  String get fillAllFields => 'Заполните URL, модель и API-ключ.';

  @override
  String get connectionOk => 'Соединение работает ✓';

  @override
  String get chatKeyRequired => 'Нужен API-ключ';

  @override
  String get chatKeyRequiredDescription =>
      'AI-чат работает с вашим ключом OpenAI-совместимого провайдера. Добавьте его в настройках — он останется на этом устройстве.';

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String get chatEyebrow => 'СПРАШИВАЙТЕ — ОТВЕЧАЮ ПОТОКОМ';

  @override
  String get topicChatIntro =>
      'Готовлю вас к собеседованию: объясняю, навожу и проверяю.';

  @override
  String get questionChatIntro =>
      'Напишите свой ответ или задайте вопрос по нему.';

  @override
  String get chatInputHint => 'Спросите что угодно…';

  @override
  String chatSettingsReadError(String error) {
    return 'Не удалось прочитать настройки: $error';
  }

  @override
  String get llmKeyRejected =>
      'Ключ отклонён (401). Проверьте API-ключ в настройках.';

  @override
  String get llmNotFound =>
      'Адрес или модель не найдены (404). Проверьте base URL и название модели.';

  @override
  String get llmRateLimited =>
      'Слишком много запросов (429). Подождите или проверьте квоту.';

  @override
  String get llmNoBalance =>
      'На аккаунте провайдера нет средств или тарифного пакета. Пополните баланс или выберите другого провайдера.';

  @override
  String get llmWebConnectionError =>
      'Ошибка соединения с провайдером. На web работают только провайдеры с CORS (OpenAI, OpenRouter, Groq). Проверьте настройки и интернет.';

  @override
  String get llmConnectionError =>
      'Ошибка соединения с провайдером. Проверьте настройки и интернет.';

  @override
  String get llmTestEmptyResponse => 'Провайдер ответил пустым сообщением.';

  @override
  String get llmEmptyReply => 'Провайдер вернул пустой ответ.';

  @override
  String llmProviderDetail(String detail) {
    return 'Ответ провайдера: $detail';
  }

  @override
  String topicChatTitle(String title) {
    return 'AI · $title';
  }

  @override
  String questionChatTitle(int index) {
    return 'AI · Вопрос $index';
  }

  @override
  String topicSystemPrompt(String title, String description) {
    return 'Ты — технический интервьюер, готовишь пользователя к собеседованию по теме \"$title\" ($description). Отвечай по-русски, кратко и по делу: объясняй примерами, задавай наводящие вопросы, проверяй понимание. Не решай за пользователя, пока он не попробовал сам.';
  }

  @override
  String questionSystemPrompt(String prompt, String reference) {
    return 'Ты — технический интервьюер. Разбираешь с пользователем вопрос: \"$prompt\". Эталонный ответ для тебя: \"$reference\". Отвечай по-русски: не выдавай сразу весь эталон — наводящими вопросами и примерами помоги пользователю сформулировать ответ самому, затем сверь с эталоном и укажи, что стоит добавить. Если пользователь просит исправить, дописать или записать правильный ответ — ответь ровно одним JSON-объектом без пояснений: поле action со значением update_answer, поле prompt — уточнённый текст вопроса, поле answer — новый эталонный ответ.';
  }

  @override
  String questionDraftPart(String draft) {
    return 'Черновик ответа пользователя: \"$draft\". ';
  }

  @override
  String get topicSuggestionStart => 'С чего начать подготовку по этой теме?';

  @override
  String get topicSuggestionQuiz =>
      'Задай мне 3 типичных вопроса с собеседования';

  @override
  String get topicSuggestionExplainer =>
      'Разбери одну тему простыми словами с примером';

  @override
  String get editTopicButton => 'Редактировать';

  @override
  String get editTopicTitle => 'Редактирование темы';

  @override
  String get editTopicNameLabel => 'Название';

  @override
  String get addTopicTitleRequired => 'Введите название темы.';

  @override
  String get editTopicDescLabel => 'Описание';

  @override
  String get editSaveTopic => 'Сохранить тему';

  @override
  String get editAddQuestion => 'Добавить вопрос';

  @override
  String get editQuestionDialogTitleNew => 'Новый вопрос';

  @override
  String get editQuestionDialogTitleEdit => 'Редактирование вопроса';

  @override
  String get editPromptLabel => 'Вопрос';

  @override
  String get editAnswerLabel => 'Эталонный ответ';

  @override
  String get editSave => 'Сохранить';

  @override
  String get editDeleteQuestion => 'Удалить';

  @override
  String get editRequired => 'Заполните вопрос и ответ.';

  @override
  String get editSaved => 'Сохранено';

  @override
  String get answerUpdateCardTitle => 'Модель предлагает новую версию ответа';

  @override
  String get answerUpdatePromptLabel => 'Уточнённый вопрос';

  @override
  String get answerUpdateButton => 'Заменить ответ';

  @override
  String get answerReplaced => 'Ответ обновлён в теме';

  @override
  String get freeChatTitle => 'Общий чат';

  @override
  String get freeChatCardSubtitle =>
      'Любые темы: карьера, учёба, хобби — о чём угодно.';

  @override
  String get freeChatIntro =>
      'Поболтаем о чём угодно: работа, учёба, хобби или просто мысли вслух.';

  @override
  String get freeSystemPrompt =>
      'Ты — дружелюбный собеседник для свободного общения на любые темы. Отвечай по-русски: живо, с любопытством и без нравоучений; поддерживай разговор, задавай встречные вопросы, делись примерами. Если тема техническая — углубляйся в детали; если лёгкая — оставайся лёгким.';

  @override
  String get freeSuggestionIcebreaker =>
      'Предложи тему для разговора и задай первый вопрос';

  @override
  String get freeSuggestionCareer =>
      'Обсудим, как справляться с выгоранием на работе';

  @override
  String get freeSuggestionFun => 'Расскажи удивительный факт о космосе';

  @override
  String get createChatTitle => 'Создать тему';

  @override
  String get createChatCardSubtitle =>
      'Опиши тему и вопросы — соберу её за тебя.';

  @override
  String get createChatIntro =>
      'Опиши, что за тему хочешь: название, уровень и сколько вопросов. Если что-то неясно — уточню.';

  @override
  String get createSystemPrompt =>
      'Ты помогаешь пользователю создавать тренировочные темы для подготовки к собеседованиям. Отвечай по-русски. Правила: (1) Если запрос ясен — ответь ровно одним JSON-объектом без markdown-обёрток и пояснений. Схема объекта: поле title — строка, название темы; поле description — строка, одно предложение о теме; поле questions — массив объектов, где каждый объект имеет поле prompt (вопрос) и поле answer (эталонный ответ в 2-4 предложения). Вопросов от 4 до 12, вопросы и ответы — на русском. (2) Если чего-то не хватает для хорошей темы (уровень, стек, глубина) — задай один короткий уточняющий вопрос обычным текстом, без JSON. (3) Дополнительный текст рядом с JSON запрещён.';

  @override
  String get createSuggestionDocker =>
      'Собери тему «Docker для новичков» — 5 вопросов';

  @override
  String get createSuggestionTypescript =>
      '10 вопросов по TypeScript для мидла';

  @override
  String get createSuggestionSql =>
      'Тема по SQL: запросы и индексы, 6 вопросов';

  @override
  String get createAddTopic => 'Добавить тему';

  @override
  String get createSaveError =>
      'Не удалось сохранить тему. Попробуйте ещё раз.';

  @override
  String get createAddTopicSuccess =>
      'Тема добавлена — она в библиотеке на главной';

  @override
  String get appendChatButton => 'Добавить вопросы с AI';

  @override
  String appendChatTitle(String title) {
    return 'Вопросы · $title';
  }

  @override
  String get appendChatIntro =>
      'Напиши, какие вопросы добавить в тему. Уточню, если что-то неясно.';

  @override
  String appendSystemPrompt(String title, String existing) {
    return 'Ты добавляешь вопросы в существующую тренировочную тему \"$title\". Отвечай по-русски. Существующие вопросы темы: $existing. Правила: (1) Если запрос ясен — ответь ровно одним JSON-объектом без markdown-обёрток и пояснений: одно поле questions — массив объектов, где каждый объект имеет поле prompt (новый вопрос) и поле answer (эталонный ответ в 2-4 предложения). Вопросов от 3 до 10, на русском, они не должны повторять перечисленные вопросы. (2) Если запрос неоднозначный — задай один короткий уточняющий вопрос обычным текстом, без JSON. (3) Дополнительный текст рядом с JSON запрещён.';
  }

  @override
  String appendSuggestionBasics(String title) {
    return 'Добавь базовые вопросы по теме «$title» для джуна';
  }

  @override
  String appendSuggestionPractice(String title) {
    return 'Добавь 3 практических кейса по теме «$title»';
  }

  @override
  String get appendSuggestionEdgeCases =>
      'Добавь вопросы про типичные ошибки и подводные камни';

  @override
  String appendAddTopic(String title) {
    return 'Добавить в тему “$title”';
  }

  @override
  String appendAddedSuccess(String title) {
    return 'Вопросы добавлены в тему “$title”';
  }

  @override
  String createAddedQuestionsSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'вопроса',
      one: 'вопрос',
      many: 'вопросов',
      few: 'вопроса',
    );
    return '$_temp0';
  }

  @override
  String get presetZaiCodingLabel => 'z.ai GLM Coding (подписка)';

  @override
  String get presetZaiLabel => 'z.ai API (оплата за токены)';

  @override
  String get presetOllamaLabel => 'Ollama (локально)';

  @override
  String get presetCustomLabel => 'Свой endpoint';
}
