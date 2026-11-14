import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ru')];

  /// No description provided for @pageNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Такой страницы нет.'**
  String get pageNotFound;

  /// No description provided for @goHome.
  ///
  /// In ru, this message translates to:
  /// **'На главную'**
  String get goHome;

  /// No description provided for @aiSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки AI'**
  String get aiSettings;

  /// No description provided for @offlineBadge.
  ///
  /// In ru, this message translates to:
  /// **'ОФЛАЙН'**
  String get offlineBadge;

  /// No description provided for @logoSemantics.
  ///
  /// In ru, this message translates to:
  /// **'Логотип Devmate'**
  String get logoSemantics;

  /// No description provided for @homeEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'ПОДГОТОВКА К ТЕХНИЧЕСКОМУ ИНТЕРВЬЮ'**
  String get homeEyebrow;

  /// No description provided for @homeTitle.
  ///
  /// In ru, this message translates to:
  /// **'Прокачай ответ.\nНе угадывай.'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Разбирай вопросы, сверяйся с эталоном и возвращайся к сложному.'**
  String get homeSubtitle;

  /// No description provided for @continueTraining.
  ///
  /// In ru, this message translates to:
  /// **'Продолжить тренировку'**
  String get continueTraining;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @libraryEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'БИБЛИОТЕКА / 10 НАПРАВЛЕНИЙ'**
  String get libraryEyebrow;

  /// No description provided for @chooseTopic.
  ///
  /// In ru, this message translates to:
  /// **'Выбери тему'**
  String get chooseTopic;

  /// No description provided for @statsEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'ТВОЯ СТАТИСТИКА'**
  String get statsEyebrow;

  /// No description provided for @statsCompletedLabel.
  ///
  /// In ru, this message translates to:
  /// **'вопросов пройдено'**
  String get statsCompletedLabel;

  /// No description provided for @totalQuestions.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} вопрос} few{{count} вопроса} many{{count} вопросов} other{{count} вопроса}}'**
  String totalQuestions(int count);

  /// No description provided for @topicEyebrowDirection.
  ///
  /// In ru, this message translates to:
  /// **'Направление'**
  String get topicEyebrowDirection;

  /// No description provided for @topicEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'БИБЛИОТЕКА / ТЕМА'**
  String get topicEyebrow;

  /// No description provided for @repeatTopic.
  ///
  /// In ru, this message translates to:
  /// **'Повторить тему'**
  String get repeatTopic;

  /// No description provided for @discussTopicWithAi.
  ///
  /// In ru, this message translates to:
  /// **'Обсудить тему с AI'**
  String get discussTopicWithAi;

  /// No description provided for @questionsEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'ВОПРОСЫ'**
  String get questionsEyebrow;

  /// No description provided for @knownXp.
  ///
  /// In ru, this message translates to:
  /// **'Знаю · 10 XP'**
  String get knownXp;

  /// No description provided for @repeatedXp.
  ///
  /// In ru, this message translates to:
  /// **'Повторил · 5 XP'**
  String get repeatedXp;

  /// No description provided for @topicProgress.
  ///
  /// In ru, this message translates to:
  /// **'{completed} из {total, plural, one{{total} вопроса} few{{total} вопросов} many{{total} вопросов} other{{total} вопроса}} пройдено'**
  String topicProgress(int completed, int total);

  /// No description provided for @practiceSaveFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить ответ'**
  String get practiceSaveFailed;

  /// No description provided for @stepYourAnswer.
  ///
  /// In ru, this message translates to:
  /// **'01 / ТВОЙ ОТВЕТ'**
  String get stepYourAnswer;

  /// No description provided for @yourAnswerHint.
  ///
  /// In ru, this message translates to:
  /// **'Сформулируй своими словами. Здесь нет автоматической проверки — сначала попробуй вспомнить сам.'**
  String get yourAnswerHint;

  /// No description provided for @yourAnswerLabel.
  ///
  /// In ru, this message translates to:
  /// **'Твой ответ'**
  String get yourAnswerLabel;

  /// No description provided for @answerPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Начни писать здесь...'**
  String get answerPlaceholder;

  /// No description provided for @compareWithReference.
  ///
  /// In ru, this message translates to:
  /// **'Сверить с эталоном'**
  String get compareWithReference;

  /// No description provided for @discussWithAi.
  ///
  /// In ru, this message translates to:
  /// **'Разобрать с AI'**
  String get discussWithAi;

  /// No description provided for @stepComparison.
  ///
  /// In ru, this message translates to:
  /// **'02 / СРАВНЕНИЕ'**
  String get stepComparison;

  /// No description provided for @yourAnswerEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'ТВОЙ ОТВЕТ'**
  String get yourAnswerEyebrow;

  /// No description provided for @referenceAnswerEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'ЭТАЛОННЫЙ ОТВЕТ'**
  String get referenceAnswerEyebrow;

  /// No description provided for @howCloseQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Насколько близко получилось?'**
  String get howCloseQuestion;

  /// No description provided for @knewAnswerXp.
  ///
  /// In ru, this message translates to:
  /// **'Знал ответ · +10 XP'**
  String get knewAnswerXp;

  /// No description provided for @needsRepeat.
  ///
  /// In ru, this message translates to:
  /// **'Нужно повторить'**
  String get needsRepeat;

  /// No description provided for @stepConsolidation.
  ///
  /// In ru, this message translates to:
  /// **'03 / ЗАКРЕПЛЕНИЕ'**
  String get stepConsolidation;

  /// No description provided for @consolidationHint.
  ///
  /// In ru, this message translates to:
  /// **'Вспомни эталонный ответ и запиши его снова своими словами. Мы не сравниваем формулировки автоматически.'**
  String get consolidationHint;

  /// No description provided for @whatToRemember.
  ///
  /// In ru, this message translates to:
  /// **'Что важно запомнить?'**
  String get whatToRemember;

  /// No description provided for @writeEssencePlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'Запиши суть ответа...'**
  String get writeEssencePlaceholder;

  /// No description provided for @consolidateXp.
  ///
  /// In ru, this message translates to:
  /// **'Закрепить · +5 XP'**
  String get consolidateXp;

  /// No description provided for @viewReferenceAgain.
  ///
  /// In ru, this message translates to:
  /// **'Посмотреть эталон снова'**
  String get viewReferenceAgain;

  /// No description provided for @doneTitle.
  ///
  /// In ru, this message translates to:
  /// **'Отлично. Ответ засчитан.'**
  String get doneTitle;

  /// No description provided for @doneSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Сложное становится понятнее.'**
  String get doneSubtitle;

  /// No description provided for @progressSavedNote.
  ///
  /// In ru, this message translates to:
  /// **'Прогресс сохранён на этом устройстве.'**
  String get progressSavedNote;

  /// No description provided for @backToTopic.
  ///
  /// In ru, this message translates to:
  /// **'К теме'**
  String get backToTopic;

  /// No description provided for @nextQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Следующий вопрос'**
  String get nextQuestion;

  /// No description provided for @questionProgress.
  ///
  /// In ru, this message translates to:
  /// **'ВОПРОС {current} / {total}'**
  String questionProgress(int current, int total);

  /// No description provided for @progressLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить прогресс. Попробуйте ещё раз.'**
  String get progressLoadError;

  /// No description provided for @answerSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить ответ. Попробуйте ещё раз.'**
  String get answerSaveError;

  /// No description provided for @settingsTitle.
  ///
  /// In ru, this message translates to:
  /// **'AI-провайдер (BYOK)'**
  String get settingsTitle;

  /// No description provided for @settingsEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'ЛЮБОЙ OPENAI-СОВМЕСТИМЫЙ ENDPOINT'**
  String get settingsEyebrow;

  /// No description provided for @keyPrivacyNote.
  ///
  /// In ru, this message translates to:
  /// **'Ключ хранится только на этом устройстве и уходит напрямую выбранному провайдеру.'**
  String get keyPrivacyNote;

  /// No description provided for @webCorsNote.
  ///
  /// In ru, this message translates to:
  /// **'На web работают только провайдеры с CORS: OpenAI, OpenRouter, Groq. z.ai и DeepSeek блокируют запросы из браузера — используйте приложение на iOS/Android или другой провайдер.'**
  String get webCorsNote;

  /// No description provided for @worksInBrowserSuffix.
  ///
  /// In ru, this message translates to:
  /// **'· работает в браузере'**
  String get worksInBrowserSuffix;

  /// No description provided for @providerLabel.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер'**
  String get providerLabel;

  /// No description provided for @baseUrlLabel.
  ///
  /// In ru, this message translates to:
  /// **'Base URL'**
  String get baseUrlLabel;

  /// No description provided for @baseUrlHint.
  ///
  /// In ru, this message translates to:
  /// **'https://api.z.ai/api/paas/v4'**
  String get baseUrlHint;

  /// No description provided for @modelLabel.
  ///
  /// In ru, this message translates to:
  /// **'Модель'**
  String get modelLabel;

  /// No description provided for @modelHint.
  ///
  /// In ru, this message translates to:
  /// **'glm-5.3-flash'**
  String get modelHint;

  /// No description provided for @apiKeyLabel.
  ///
  /// In ru, this message translates to:
  /// **'API-ключ'**
  String get apiKeyLabel;

  /// No description provided for @apiKeyHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите ваш ключ'**
  String get apiKeyHint;

  /// No description provided for @saving.
  ///
  /// In ru, this message translates to:
  /// **'Сохраняем...'**
  String get saving;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @testing.
  ///
  /// In ru, this message translates to:
  /// **'Проверяем...'**
  String get testing;

  /// No description provided for @testConnection.
  ///
  /// In ru, this message translates to:
  /// **'Проверить соединение'**
  String get testConnection;

  /// No description provided for @settingsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать настройки. Проверьте доступность хранилища.'**
  String get settingsLoadError;

  /// No description provided for @settingsSaved.
  ///
  /// In ru, this message translates to:
  /// **'Настройки сохранены на этом устройстве.'**
  String get settingsSaved;

  /// No description provided for @settingsSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить настройки на этом устройстве.'**
  String get settingsSaveError;

  /// No description provided for @fillAllFields.
  ///
  /// In ru, this message translates to:
  /// **'Заполните URL, модель и API-ключ.'**
  String get fillAllFields;

  /// No description provided for @connectionOk.
  ///
  /// In ru, this message translates to:
  /// **'Соединение работает ✓'**
  String get connectionOk;

  /// No description provided for @chatKeyRequired.
  ///
  /// In ru, this message translates to:
  /// **'Нужен API-ключ'**
  String get chatKeyRequired;

  /// No description provided for @chatKeyRequiredDescription.
  ///
  /// In ru, this message translates to:
  /// **'AI-чат работает с вашим ключом OpenAI-совместимого провайдера. Добавьте его в настройках — он останется на этом устройстве.'**
  String get chatKeyRequiredDescription;

  /// No description provided for @openSettings.
  ///
  /// In ru, this message translates to:
  /// **'Открыть настройки'**
  String get openSettings;

  /// No description provided for @chatEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'СПРАШИВАЙТЕ — ОТВЕЧАЮ ПОТОКОМ'**
  String get chatEyebrow;

  /// No description provided for @topicChatIntro.
  ///
  /// In ru, this message translates to:
  /// **'Готовлю вас к собеседованию: объясняю, навожу и проверяю.'**
  String get topicChatIntro;

  /// No description provided for @questionChatIntro.
  ///
  /// In ru, this message translates to:
  /// **'Напишите свой ответ или задайте вопрос по нему.'**
  String get questionChatIntro;

  /// No description provided for @chatInputHint.
  ///
  /// In ru, this message translates to:
  /// **'Спросите что угодно…'**
  String get chatInputHint;

  /// No description provided for @chatSettingsReadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать настройки: {error}'**
  String chatSettingsReadError(String error);

  /// No description provided for @llmKeyRejected.
  ///
  /// In ru, this message translates to:
  /// **'Ключ отклонён (401). Проверьте API-ключ в настройках.'**
  String get llmKeyRejected;

  /// No description provided for @llmNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Адрес или модель не найдены (404). Проверьте base URL и название модели.'**
  String get llmNotFound;

  /// No description provided for @llmRateLimited.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много запросов (429). Подождите или проверьте квоту.'**
  String get llmRateLimited;

  /// No description provided for @llmNoBalance.
  ///
  /// In ru, this message translates to:
  /// **'На аккаунте провайдера нет средств или тарифного пакета. Пополните баланс или выберите другого провайдера.'**
  String get llmNoBalance;

  /// No description provided for @llmWebConnectionError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка соединения с провайдером. На web работают только провайдеры с CORS (OpenAI, OpenRouter, Groq). Проверьте настройки и интернет.'**
  String get llmWebConnectionError;

  /// No description provided for @llmConnectionError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка соединения с провайдером. Проверьте настройки и интернет.'**
  String get llmConnectionError;

  /// No description provided for @llmTestEmptyResponse.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер ответил пустым сообщением.'**
  String get llmTestEmptyResponse;

  /// No description provided for @llmEmptyReply.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер вернул пустой ответ.'**
  String get llmEmptyReply;

  /// No description provided for @topicChatTitle.
  ///
  /// In ru, this message translates to:
  /// **'AI · {title}'**
  String topicChatTitle(String title);

  /// No description provided for @questionChatTitle.
  ///
  /// In ru, this message translates to:
  /// **'AI · Вопрос {index}'**
  String questionChatTitle(int index);

  /// No description provided for @topicSystemPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Ты — технический интервьюер, готовишь пользователя к собеседованию по теме \"{title}\" ({description}). Отвечай по-русски, кратко и по делу: объясняй примерами, задавай наводящие вопросы, проверяй понимание. Не решай за пользователя, пока он не попробовал сам.'**
  String topicSystemPrompt(String title, String description);

  /// No description provided for @questionSystemPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Ты — технический интервьюер. Разбираешь с пользователем вопрос: \"{prompt}\". Эталонный ответ для тебя: \"{reference}\". Отвечай по-русски: не выдавай сразу весь эталон — наводящими вопросами и примерами помоги пользователю сформулировать ответ самому, затем сверь с эталоном и укажи, что стоит добавить.'**
  String questionSystemPrompt(String prompt, String reference);

  /// No description provided for @questionDraftPart.
  ///
  /// In ru, this message translates to:
  /// **'Черновик ответа пользователя: \"{draft}\". '**
  String questionDraftPart(String draft);

  /// No description provided for @topicSuggestionStart.
  ///
  /// In ru, this message translates to:
  /// **'С чего начать подготовку по этой теме?'**
  String get topicSuggestionStart;

  /// No description provided for @topicSuggestionQuiz.
  ///
  /// In ru, this message translates to:
  /// **'Задай мне 3 типичных вопроса с собеседования'**
  String get topicSuggestionQuiz;

  /// No description provided for @topicSuggestionExplainer.
  ///
  /// In ru, this message translates to:
  /// **'Разбери одну тему простыми словами с примером'**
  String get topicSuggestionExplainer;

  /// No description provided for @freeChatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Общий чат'**
  String get freeChatTitle;

  /// No description provided for @freeChatCardSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Любые темы: карьера, учёба, хобби — о чём угодно.'**
  String get freeChatCardSubtitle;

  /// No description provided for @freeChatIntro.
  ///
  /// In ru, this message translates to:
  /// **'Поболтаем о чём угодно: работа, учёба, хобби или просто мысли вслух.'**
  String get freeChatIntro;

  /// No description provided for @freeSystemPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Ты — дружелюбный собеседник для свободного общения на любые темы. Отвечай по-русски: живо, с любопытством и без нравоучений; поддерживай разговор, задавай встречные вопросы, делись примерами. Если тема техническая — углубляйся в детали; если лёгкая — оставайся лёгким.'**
  String get freeSystemPrompt;

  /// No description provided for @freeSuggestionIcebreaker.
  ///
  /// In ru, this message translates to:
  /// **'Предложи тему для разговора и задай первый вопрос'**
  String get freeSuggestionIcebreaker;

  /// No description provided for @freeSuggestionCareer.
  ///
  /// In ru, this message translates to:
  /// **'Обсудим, как справляться с выгоранием на работе'**
  String get freeSuggestionCareer;

  /// No description provided for @freeSuggestionFun.
  ///
  /// In ru, this message translates to:
  /// **'Расскажи удивительный факт о космосе'**
  String get freeSuggestionFun;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
