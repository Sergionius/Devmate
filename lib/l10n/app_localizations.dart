import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @chatRetry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get chatRetry;

  /// No description provided for @chatNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый чат'**
  String get chatNew;

  /// No description provided for @chatHistoryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Пока нет бесед. Начните новый чат, чтобы сохранить разговор.'**
  String get chatHistoryEmpty;

  /// No description provided for @chatHistoryReadError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить историю чатов'**
  String get chatHistoryReadError;

  /// No description provided for @chatHistorySaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить переписку'**
  String get chatHistorySaveError;

  /// No description provided for @chatDeleteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить беседу'**
  String get chatDeleteTitle;

  /// No description provided for @chatDeleteWarning.
  ///
  /// In ru, this message translates to:
  /// **'Беседа и все её сообщения будут удалены без возможности восстановления.'**
  String get chatDeleteWarning;

  /// No description provided for @backupIncludeChats.
  ///
  /// In ru, this message translates to:
  /// **'Включить историю общего чата'**
  String get backupIncludeChats;

  /// No description provided for @backupChatsInFile.
  ///
  /// In ru, this message translates to:
  /// **'Бесед в файле: {count}. При замене текущая история чатов будет удалена и заменена беседами из файла.'**
  String backupChatsInFile(int count);

  /// No description provided for @chatHistoryWriteError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось изменить историю чатов'**
  String get chatHistoryWriteError;

  /// No description provided for @chatCopy.
  ///
  /// In ru, this message translates to:
  /// **'Копировать'**
  String get chatCopy;

  /// No description provided for @chatShare.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться'**
  String get chatShare;

  /// No description provided for @vacancyTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вопросы из вакансии'**
  String get vacancyTitle;

  /// No description provided for @vacancyCardSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Вставьте описание вакансии и составьте вопросы с AI'**
  String get vacancyCardSubtitle;

  /// No description provided for @vacancyIntro.
  ///
  /// In ru, this message translates to:
  /// **'Вставьте текст вакансии. Перед сохранением можно проверить и изменить каждый вопрос. Текст будет отправлен вашему AI-провайдеру.'**
  String get vacancyIntro;

  /// No description provided for @vacancyText.
  ///
  /// In ru, this message translates to:
  /// **'Текст вакансии'**
  String get vacancyText;

  /// No description provided for @vacancyHint.
  ///
  /// In ru, this message translates to:
  /// **'Требования, обязанности, стек технологий…'**
  String get vacancyHint;

  /// No description provided for @vacancyGenerate.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать вопросы'**
  String get vacancyGenerate;

  /// No description provided for @vacancyGenerating.
  ///
  /// In ru, this message translates to:
  /// **'Генерируем вопросы…'**
  String get vacancyGenerating;

  /// No description provided for @vacancyPreview.
  ///
  /// In ru, this message translates to:
  /// **'Предпросмотр вопросов'**
  String get vacancyPreview;

  /// No description provided for @vacancyDestination.
  ///
  /// In ru, this message translates to:
  /// **'Куда сохранить'**
  String get vacancyDestination;

  /// No description provided for @vacancyNewTopic.
  ///
  /// In ru, this message translates to:
  /// **'Новая тема'**
  String get vacancyNewTopic;

  /// No description provided for @vacancyTopicTitle.
  ///
  /// In ru, this message translates to:
  /// **'Название темы'**
  String get vacancyTopicTitle;

  /// No description provided for @vacancyTopicDescription.
  ///
  /// In ru, this message translates to:
  /// **'Описание темы'**
  String get vacancyTopicDescription;

  /// No description provided for @vacancyQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Вопрос'**
  String get vacancyQuestion;

  /// No description provided for @vacancyAnswer.
  ///
  /// In ru, this message translates to:
  /// **'Эталонный ответ'**
  String get vacancyAnswer;

  /// No description provided for @vacancyEdit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить вопрос'**
  String get vacancyEdit;

  /// No description provided for @vacancyApply.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get vacancyApply;

  /// No description provided for @vacancyRemove.
  ///
  /// In ru, this message translates to:
  /// **'Удалить вопрос'**
  String get vacancyRemove;

  /// No description provided for @vacancySave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить вопросы в тему'**
  String get vacancySave;

  /// No description provided for @vacancyValidate.
  ///
  /// In ru, this message translates to:
  /// **'Укажите название темы и оставьте хотя бы один заполненный вопрос.'**
  String get vacancyValidate;

  /// No description provided for @vacancyNoQuestions.
  ///
  /// In ru, this message translates to:
  /// **'Все вопросы удалены. Сгенерируйте их заново, чтобы сохранить тему.'**
  String get vacancyNoQuestions;

  /// No description provided for @vacancyAiDisabled.
  ///
  /// In ru, this message translates to:
  /// **'AI отключён в настройках. Генерация вопросов из вакансии недоступна.'**
  String get vacancyAiDisabled;

  /// No description provided for @vacancyEnterText.
  ///
  /// In ru, this message translates to:
  /// **'Вставьте текст вакансии.'**
  String get vacancyEnterText;

  /// No description provided for @vacancyReplaceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Заменить предпросмотр?'**
  String get vacancyReplaceTitle;

  /// No description provided for @vacancyReplaceWarning.
  ///
  /// In ru, this message translates to:
  /// **'Текущие вопросы и ваши правки исчезнут. Сгенерировать вопросы заново?'**
  String get vacancyReplaceWarning;

  /// No description provided for @vacancyReplaceAction.
  ///
  /// In ru, this message translates to:
  /// **'Сгенерировать заново'**
  String get vacancyReplaceAction;

  /// No description provided for @vacancyKeyRequired.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте API-ключ в настройках AI, чтобы создавать вопросы из вакансии.'**
  String get vacancyKeyRequired;

  /// No description provided for @vacancyGenerationError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить вопросы. Проверьте подключение и попробуйте снова.'**
  String get vacancyGenerationError;

  /// No description provided for @vacancyInvalidReply.
  ///
  /// In ru, this message translates to:
  /// **'AI вернул ответ без списка вопросов. Попробуйте сгенерировать их снова.'**
  String get vacancyInvalidReply;

  /// No description provided for @vacancySaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить вопросы. Проверьте тему и повторите попытку.'**
  String get vacancySaveError;

  /// No description provided for @vacancyInstruction.
  ///
  /// In ru, this message translates to:
  /// **'Ты составляешь вопросы для подготовки к техническому собеседованию по тексту вакансии. Отвечай на русском. Выдели реальные требования и технологии; не выдумывай то, чего нет в вакансии. Верни строго один JSON-объект без Markdown и пояснений: title (короткое название темы), description (краткое описание), questions (массив из 4–10 объектов с непустыми prompt и answer). Ответы должны быть точными, по 2–4 предложения. Вопросы не должны повторяться. Если вакансия недостаточно информативна, верни вопросы только по явно указанным требованиям.'**
  String get vacancyInstruction;

  /// No description provided for @searchTitle.
  ///
  /// In ru, this message translates to:
  /// **'Поиск'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по темам и вопросам'**
  String get searchHint;

  /// No description provided for @searchClear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить поиск'**
  String get searchClear;

  /// No description provided for @searchAnswers.
  ///
  /// In ru, this message translates to:
  /// **'Искать также в ответах'**
  String get searchAnswers;

  /// No description provided for @searchStart.
  ///
  /// In ru, this message translates to:
  /// **'Введите слово или фразу для поиска по библиотеке.'**
  String get searchStart;

  /// No description provided for @searchEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено.'**
  String get searchEmpty;

  /// No description provided for @searchTopics.
  ///
  /// In ru, this message translates to:
  /// **'Темы'**
  String get searchTopics;

  /// No description provided for @searchQuestions.
  ///
  /// In ru, this message translates to:
  /// **'Вопросы'**
  String get searchQuestions;

  /// No description provided for @questionsManagement.
  ///
  /// In ru, this message translates to:
  /// **'Управление вопросами'**
  String get questionsManagement;

  /// No description provided for @questionsJsonHint.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт копирует JSON в буфер обмена. Импорт предлагает два режима: «Заменить всё» заменяет все темы и вопросы из вставленного JSON и сбрасывает прогресс; «Добавить» дописывает вопросы в темы с совпадающими названиями, создаёт отсутствующие темы и сохраняет существующий каталог и прогресс.'**
  String get questionsJsonHint;

  /// No description provided for @exportQuestions.
  ///
  /// In ru, this message translates to:
  /// **'Скопировать вопросы в JSON'**
  String get exportQuestions;

  /// No description provided for @importQuestions.
  ///
  /// In ru, this message translates to:
  /// **'Импортировать JSON'**
  String get importQuestions;

  /// No description provided for @pasteQuestionsJson.
  ///
  /// In ru, this message translates to:
  /// **'Вставьте JSON с темами и вопросами'**
  String get pasteQuestionsJson;

  /// No description provided for @questionsCopied.
  ///
  /// In ru, this message translates to:
  /// **'JSON вопросов скопирован в буфер обмена'**
  String get questionsCopied;

  /// No description provided for @importAppendAction.
  ///
  /// In ru, this message translates to:
  /// **'Добавить'**
  String get importAppendAction;

  /// No description provided for @importReplaceAction.
  ///
  /// In ru, this message translates to:
  /// **'Заменить всё'**
  String get importReplaceAction;

  /// No description provided for @questionsImported.
  ///
  /// In ru, this message translates to:
  /// **'Каталог заменён из JSON, прогресс сброшен'**
  String get questionsImported;

  /// No description provided for @questionsAppended.
  ///
  /// In ru, this message translates to:
  /// **'Вопросы добавлены, существующие темы и прогресс сохранены'**
  String get questionsAppended;

  /// No description provided for @importFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось импортировать вопросы'**
  String get importFailed;

  /// No description provided for @resetTopicProgress.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить прогресс раздела'**
  String get resetTopicProgress;

  /// No description provided for @resetTopicProgressWarning.
  ///
  /// In ru, this message translates to:
  /// **'Удалить результаты тренировок только в разделе «{title}»? Прогресс других разделов, вопросы и настройки сохранятся.'**
  String resetTopicProgressWarning(String title);

  /// No description provided for @resetTopicProgressDone.
  ///
  /// In ru, this message translates to:
  /// **'Прогресс раздела сброшен'**
  String get resetTopicProgressDone;

  /// No description provided for @resetProgress.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить только прогресс'**
  String get resetProgress;

  /// No description provided for @resetProgressWarning.
  ///
  /// In ru, this message translates to:
  /// **'Удалить все результаты тренировок и очки? Вопросы, темы и настройки AI сохранятся. Это действие нельзя отменить.'**
  String get resetProgressWarning;

  /// No description provided for @resetProgressDone.
  ///
  /// In ru, this message translates to:
  /// **'Прогресс сброшен'**
  String get resetProgressDone;

  /// No description provided for @resetProgressFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сбросить прогресс'**
  String get resetProgressFailed;

  /// No description provided for @resetAll.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить всё'**
  String get resetAll;

  /// No description provided for @resetWarning.
  ///
  /// In ru, this message translates to:
  /// **'Удалить пользовательские темы, вопросы, изменения, прогресс и настройки AI? Встроенные вопросы вернутся к исходному состоянию. Это действие нельзя отменить.'**
  String get resetWarning;

  /// No description provided for @resetDone.
  ///
  /// In ru, this message translates to:
  /// **'Исходное состояние восстановлено'**
  String get resetDone;

  /// No description provided for @resetFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось завершить сброс'**
  String get resetFailed;

  /// No description provided for @cancelAction.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancelAction;

  /// No description provided for @agentJsonInstruction.
  ///
  /// In ru, this message translates to:
  /// **'Инструкция для агента: создай валидный JSON без Markdown. Корневой объект содержит version со значением 1 и topics — непустой массив тем. Каждая тема содержит непустой title, строковое description (можно пустое) и непустой массив questions. Каждый вопрос содержит непустые prompt и answer. Для каждой темы подготовь 4–12 неповторяющихся вопросов на русском; ответы — точные, по 2–4 предложения. ID не нужны — приложение создаст их при импорте.'**
  String get agentJsonInstruction;

  /// No description provided for @shareInstruction.
  ///
  /// In ru, this message translates to:
  /// **'Поделиться инструкцией'**
  String get shareInstruction;

  /// No description provided for @shareFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось открыть меню «Поделиться»'**
  String get shareFailed;

  /// No description provided for @exportQuestionsFile.
  ///
  /// In ru, this message translates to:
  /// **'Экспорт в файл'**
  String get exportQuestionsFile;

  /// No description provided for @importQuestionsFile.
  ///
  /// In ru, this message translates to:
  /// **'Импорт из файла'**
  String get importQuestionsFile;

  /// No description provided for @fileReadFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось прочитать файл'**
  String get fileReadFailed;

  /// No description provided for @backupSectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Полный бэкап'**
  String get backupSectionTitle;

  /// No description provided for @backupHint.
  ///
  /// In ru, this message translates to:
  /// **'Один JSON-файл со своими темами, прогрессом и настройками — удобно для переноса на другое устройство. API-ключи в файл не попадают. «Заменить всё» восстанавливает ровно то, что в файле. «Объединить» добавляет темы поверх текущих: уже существующие вопросы сохраняют лучший результат, а прогресс новых вопросов начинается заново; настройки не меняются.'**
  String get backupHint;

  /// No description provided for @exportBackup.
  ///
  /// In ru, this message translates to:
  /// **'Экспортировать всё'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In ru, this message translates to:
  /// **'Импортировать бэкап'**
  String get importBackup;

  /// No description provided for @backupSummary.
  ///
  /// In ru, this message translates to:
  /// **'Тем в файле: {topics}, вопросов с отметками прогресса: {answers}'**
  String backupSummary(int topics, int answers);

  /// No description provided for @backupMergeAction.
  ///
  /// In ru, this message translates to:
  /// **'Объединить'**
  String get backupMergeAction;

  /// No description provided for @backupReplaceAction.
  ///
  /// In ru, this message translates to:
  /// **'Заменить всё'**
  String get backupReplaceAction;

  /// No description provided for @backupImportedReplace.
  ///
  /// In ru, this message translates to:
  /// **'Бэкап восстановлен'**
  String get backupImportedReplace;

  /// No description provided for @backupImportedMerge.
  ///
  /// In ru, this message translates to:
  /// **'Темы добавлены. Лучший результат сохранён для уже существующих вопросов; прогресс новых вопросов начнётся заново'**
  String get backupImportedMerge;

  /// No description provided for @backupInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Это не файл бэкапа Devmate'**
  String get backupInvalid;

  /// No description provided for @backupImportFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось восстановить бэкап'**
  String get backupImportFailed;

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
  /// **'Настройки'**
  String get settingsTitle;

  /// No description provided for @settingsAiTitle.
  ///
  /// In ru, this message translates to:
  /// **'AI-провайдер (BYOK)'**
  String get settingsAiTitle;

  /// No description provided for @settingsDisableAi.
  ///
  /// In ru, this message translates to:
  /// **'Отключить AI'**
  String get settingsDisableAi;

  /// No description provided for @settingsAiSection.
  ///
  /// In ru, this message translates to:
  /// **'AI-провайдер'**
  String get settingsAiSection;

  /// No description provided for @settingsAiSectionNote.
  ///
  /// In ru, this message translates to:
  /// **'Провайдер, модель и API-ключ'**
  String get settingsAiSectionNote;

  /// No description provided for @settingsDataTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вопросы и данные'**
  String get settingsDataTitle;

  /// No description provided for @settingsDataSectionNote.
  ///
  /// In ru, this message translates to:
  /// **'Импорт, экспорт и сброс'**
  String get settingsDataSectionNote;

  /// No description provided for @settingsEyebrow.
  ///
  /// In ru, this message translates to:
  /// **'ЛЮБОЙ OPENAI-СОВМЕСТИМЫЙ ENDPOINT'**
  String get settingsEyebrow;

  /// No description provided for @settingsLanguage.
  ///
  /// In ru, this message translates to:
  /// **'Язык приложения'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как в системе'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageRestartNote.
  ///
  /// In ru, this message translates to:
  /// **'Интерфейс переключится сразу; вопросы будут на выбранном языке после перезапуска приложения.'**
  String get settingsLanguageRestartNote;

  /// No description provided for @settingsTheme.
  ///
  /// In ru, this message translates to:
  /// **'Оформление'**
  String get settingsTheme;

  /// No description provided for @settingsThemeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Как на устройстве'**
  String get settingsThemeSystem;

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

  /// No description provided for @llmProviderDetail.
  ///
  /// In ru, this message translates to:
  /// **'Ответ провайдера: {detail}'**
  String llmProviderDetail(String detail);

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
  /// **'Ты — технический интервьюер. Разбираешь с пользователем вопрос: \"{prompt}\". Эталонный ответ для тебя: \"{reference}\". Отвечай по-русски: не выдавай сразу весь эталон — наводящими вопросами и примерами помоги пользователю сформулировать ответ самому, затем сверь с эталоном и укажи, что стоит добавить. Если пользователь просит исправить, дописать или записать правильный ответ — ответь ровно одним JSON-объектом без пояснений: поле action со значением update_answer, поле prompt — уточнённый текст вопроса, поле answer — новый эталонный ответ.'**
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

  /// No description provided for @editTopicButton.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать'**
  String get editTopicButton;

  /// No description provided for @editTopicTitle.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование темы'**
  String get editTopicTitle;

  /// No description provided for @editTopicNameLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get editTopicNameLabel;

  /// No description provided for @addTopicTitleRequired.
  ///
  /// In ru, this message translates to:
  /// **'Введите название темы.'**
  String get addTopicTitleRequired;

  /// No description provided for @editTopicDescLabel.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get editTopicDescLabel;

  /// No description provided for @editSaveTopic.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить тему'**
  String get editSaveTopic;

  /// No description provided for @editAddQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Добавить вопрос'**
  String get editAddQuestion;

  /// No description provided for @editQuestionDialogTitleNew.
  ///
  /// In ru, this message translates to:
  /// **'Новый вопрос'**
  String get editQuestionDialogTitleNew;

  /// No description provided for @editQuestionDialogTitleEdit.
  ///
  /// In ru, this message translates to:
  /// **'Редактирование вопроса'**
  String get editQuestionDialogTitleEdit;

  /// No description provided for @editPromptLabel.
  ///
  /// In ru, this message translates to:
  /// **'Вопрос'**
  String get editPromptLabel;

  /// No description provided for @editAnswerLabel.
  ///
  /// In ru, this message translates to:
  /// **'Эталонный ответ'**
  String get editAnswerLabel;

  /// No description provided for @editSave.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get editSave;

  /// No description provided for @editDeleteQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get editDeleteQuestion;

  /// No description provided for @editRequired.
  ///
  /// In ru, this message translates to:
  /// **'Заполните вопрос и ответ.'**
  String get editRequired;

  /// No description provided for @editSaved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get editSaved;

  /// No description provided for @answerUpdateCardTitle.
  ///
  /// In ru, this message translates to:
  /// **'Модель предлагает новую версию ответа'**
  String get answerUpdateCardTitle;

  /// No description provided for @answerUpdatePromptLabel.
  ///
  /// In ru, this message translates to:
  /// **'Уточнённый вопрос'**
  String get answerUpdatePromptLabel;

  /// No description provided for @answerUpdateButton.
  ///
  /// In ru, this message translates to:
  /// **'Заменить ответ'**
  String get answerUpdateButton;

  /// No description provided for @answerReplaced.
  ///
  /// In ru, this message translates to:
  /// **'Ответ обновлён в теме'**
  String get answerReplaced;

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

  /// No description provided for @createChatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Создать тему'**
  String get createChatTitle;

  /// No description provided for @createChatCardSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Опиши тему и вопросы — соберу её за тебя.'**
  String get createChatCardSubtitle;

  /// No description provided for @createChatIntro.
  ///
  /// In ru, this message translates to:
  /// **'Опиши, что за тему хочешь: название, уровень и сколько вопросов. Если что-то неясно — уточню.'**
  String get createChatIntro;

  /// No description provided for @createSystemPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Ты помогаешь пользователю создавать тренировочные темы для подготовки к собеседованиям. Отвечай по-русски. Правила: (1) Если запрос ясен — ответь ровно одним JSON-объектом без markdown-обёрток и пояснений. Схема объекта: поле title — строка, название темы; поле description — строка, одно предложение о теме; поле questions — массив объектов, где каждый объект имеет поле prompt (вопрос) и поле answer (эталонный ответ в 2-4 предложения). Вопросов от 4 до 12, вопросы и ответы — на русском. (2) Если чего-то не хватает для хорошей темы (уровень, стек, глубина) — задай один короткий уточняющий вопрос обычным текстом, без JSON. (3) Дополнительный текст рядом с JSON запрещён.'**
  String get createSystemPrompt;

  /// No description provided for @createSuggestionDocker.
  ///
  /// In ru, this message translates to:
  /// **'Собери тему «Docker для новичков» — 5 вопросов'**
  String get createSuggestionDocker;

  /// No description provided for @createSuggestionTypescript.
  ///
  /// In ru, this message translates to:
  /// **'10 вопросов по TypeScript для мидла'**
  String get createSuggestionTypescript;

  /// No description provided for @createSuggestionSql.
  ///
  /// In ru, this message translates to:
  /// **'Тема по SQL: запросы и индексы, 6 вопросов'**
  String get createSuggestionSql;

  /// No description provided for @createAddTopic.
  ///
  /// In ru, this message translates to:
  /// **'Добавить тему'**
  String get createAddTopic;

  /// No description provided for @createSaveError.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось сохранить тему. Попробуйте ещё раз.'**
  String get createSaveError;

  /// No description provided for @createAddTopicSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Тема добавлена — она в библиотеке на главной'**
  String get createAddTopicSuccess;

  /// No description provided for @appendChatButton.
  ///
  /// In ru, this message translates to:
  /// **'Добавить вопросы с AI'**
  String get appendChatButton;

  /// No description provided for @appendChatTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вопросы · {title}'**
  String appendChatTitle(String title);

  /// No description provided for @appendChatIntro.
  ///
  /// In ru, this message translates to:
  /// **'Напиши, какие вопросы добавить в тему. Уточню, если что-то неясно.'**
  String get appendChatIntro;

  /// No description provided for @appendSystemPrompt.
  ///
  /// In ru, this message translates to:
  /// **'Ты добавляешь вопросы в существующую тренировочную тему \"{title}\". Отвечай по-русски. Существующие вопросы темы: {existing}. Правила: (1) Если запрос ясен — ответь ровно одним JSON-объектом без markdown-обёрток и пояснений: одно поле questions — массив объектов, где каждый объект имеет поле prompt (новый вопрос) и поле answer (эталонный ответ в 2-4 предложения). Вопросов от 3 до 10, на русском, они не должны повторять перечисленные вопросы. (2) Если запрос неоднозначный — задай один короткий уточняющий вопрос обычным текстом, без JSON. (3) Дополнительный текст рядом с JSON запрещён.'**
  String appendSystemPrompt(String title, String existing);

  /// No description provided for @appendSuggestionBasics.
  ///
  /// In ru, this message translates to:
  /// **'Добавь базовые вопросы по теме «{title}» для джуна'**
  String appendSuggestionBasics(String title);

  /// No description provided for @appendSuggestionPractice.
  ///
  /// In ru, this message translates to:
  /// **'Добавь 3 практических кейса по теме «{title}»'**
  String appendSuggestionPractice(String title);

  /// No description provided for @appendSuggestionEdgeCases.
  ///
  /// In ru, this message translates to:
  /// **'Добавь вопросы про типичные ошибки и подводные камни'**
  String get appendSuggestionEdgeCases;

  /// No description provided for @appendAddTopic.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в тему “{title}”'**
  String appendAddTopic(String title);

  /// No description provided for @appendAddedSuccess.
  ///
  /// In ru, this message translates to:
  /// **'Вопросы добавлены в тему “{title}”'**
  String appendAddedSuccess(String title);

  /// No description provided for @createAddedQuestionsSuffix.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, few{вопроса} many{вопросов} one{вопрос} other{вопроса}}'**
  String createAddedQuestionsSuffix(int count);

  /// No description provided for @presetZaiCodingLabel.
  ///
  /// In ru, this message translates to:
  /// **'z.ai GLM Coding (подписка)'**
  String get presetZaiCodingLabel;

  /// No description provided for @presetZaiLabel.
  ///
  /// In ru, this message translates to:
  /// **'z.ai API (оплата за токены)'**
  String get presetZaiLabel;

  /// No description provided for @presetOllamaLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ollama (локально)'**
  String get presetOllamaLabel;

  /// No description provided for @presetCustomLabel.
  ///
  /// In ru, this message translates to:
  /// **'Свой endpoint'**
  String get presetCustomLabel;

  /// No description provided for @braveWebNote.
  ///
  /// In ru, this message translates to:
  /// **'Brave Search сейчас отклоняет CORS-проверку браузера. На web используйте Exa или Tavily, а Brave — на iOS/Android.'**
  String get braveWebNote;

  /// No description provided for @searchProviderLabel.
  ///
  /// In ru, this message translates to:
  /// **'Поисковый провайдер'**
  String get searchProviderLabel;

  /// No description provided for @searchKeyLabel.
  ///
  /// In ru, this message translates to:
  /// **'Ключ поискового API'**
  String get searchKeyLabel;

  /// No description provided for @searchKeyHint.
  ///
  /// In ru, this message translates to:
  /// **'Ключ выбранного провайдера'**
  String get searchKeyHint;

  /// No description provided for @exaKeyMissing.
  ///
  /// In ru, this message translates to:
  /// **'Введите ключ поискового API'**
  String get exaKeyMissing;

  /// No description provided for @exaTestFailed.
  ///
  /// In ru, this message translates to:
  /// **'Поиск недоступен. Проверьте провайдера, ключ и соединение.'**
  String get exaTestFailed;

  /// No description provided for @exaPrivacyNote.
  ///
  /// In ru, this message translates to:
  /// **'Поиск необязателен. Ваш ключ отправляется только выбранному поисковому провайдеру; результаты передаются выбранной модели. На web работа зависит от CORS провайдера. Не распространяйте сборки с ключами из config/local.json.'**
  String get exaPrivacyNote;

  /// No description provided for @testSearchConnection.
  ///
  /// In ru, this message translates to:
  /// **'Проверить веб-поиск'**
  String get testSearchConnection;
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
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
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
