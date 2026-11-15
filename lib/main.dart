import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'data/app_preferences.dart';
import 'data/llm_settings.dart';
import 'data/progress_repository.dart';
import 'data/question_catalog.dart';
import 'data/topic_catalog.dart';
import 'router.dart';
import 'ui/design_system.dart';
import 'ui/training_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: 'assets/config/.env');
  } catch (_) {
    dotenv.loadFromString(envString: '', isOptional: true);
  }
  final llmSettings = LlmSettingsRepository();
  final appPreferences = AppPreferencesRepository();
  // null — язык системы; иначе явный выбор пользователя из настроек.
  // Сбой чтения не должен мешать старту приложения.
  AppLanguage savedLanguage = AppLanguage.system;
  try {
    savedLanguage = await appPreferences.loadLanguage();
  } catch (error) {
    debugPrint('main: чтение сохранённого языка не удалось: $error');
  }
  // Глобальное отключение AI: скрывает чаты и раздел провайдера.
  bool aiDisabled = false;
  try {
    aiDisabled = await appPreferences.loadAiDisabled();
  } catch (error) {
    debugPrint('main: чтение отключения AI не удалось: $error');
  }
  // Режим темы: тёмная по умолчанию, светлая или как на устройстве.
  // Сбой чтения не должен мешать старту приложения.
  AppThemePreference savedTheme = AppThemePreference.dark;
  try {
    savedTheme = await appPreferences.loadTheme();
  } catch (error) {
    debugPrint('main: чтение сохранённой темы не удалось: $error');
  }
  final catalogLanguage =
      savedLanguage.locale?.languageCode ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final catalog = TopicCatalog(
    userTopicsRepository: LocalUserTopicsRepository(SharedPreferencesAsync()),
    baseTopics: questionCatalogFor(catalogLanguage),
  );

  await catalog.load();
  runApp(
    DevmateApp(
      viewModel: TrainingViewModel(
        LocalProgressRepository(SharedPreferencesAsync()),
        catalogRepository: catalog,
      )..load(),
      llmSettings: llmSettings,
      catalog: catalog,
      appLocale: ValueNotifier<Locale?>(savedLanguage.locale),
      aiDisabled: ValueNotifier<bool>(aiDisabled),
      themeMode: ValueNotifier<ThemeMode>(savedTheme.mode),
      appPreferences: appPreferences,
    ),
  );
}

class DevmateApp extends StatelessWidget {
  DevmateApp({
    super.key,
    required TrainingViewModel viewModel,
    required LlmSettingsRepository llmSettings,
    required TopicCatalog catalog,
    this.locale,
    this.appLocale,
    this.aiDisabled,
    this.themeMode,
    this.appPreferences,
  }) : router = createRouter(
         viewModel,
         llmSettings,
         catalog,
         appLocale: appLocale,
         aiDisabled: aiDisabled,
         themeMode: themeMode,
         appPreferences: appPreferences,
       );

  final GoRouter router;
  final Locale? locale;

  /// Живой выбор языка из настроек; `null` в значении — язык системы.
  final ValueNotifier<Locale?>? appLocale;

  /// Глобальное отключение AI: true — AI-кнопки скрыты по всему приложению.
  final ValueNotifier<bool>? aiDisabled;

  /// Живой режим темы (тёмная/светлая/как на устройстве).
  final ValueNotifier<ThemeMode>? themeMode;

  final AppPreferencesRepository? appPreferences;

  @override
  Widget build(BuildContext context) {
    final localeNotifier = appLocale;
    final modeNotifier = themeMode;
    ThemeMode initialMode() => modeNotifier?.value ?? ThemeMode.dark;

    Widget app = _materialApp(locale, initialMode());
    if (localeNotifier != null) {
      app = ValueListenableBuilder<Locale?>(
        valueListenable: localeNotifier,
        builder: (context, value, _) =>
            _materialApp(value ?? locale, initialMode()),
      );
    }
    if (modeNotifier != null) {
      // Внешний слой слушает режим темы, внутренний — язык, чтобы оба
      // переключения применялись мгновенно и независимо друг от друга.
      if (localeNotifier != null) {
        app = ValueListenableBuilder<ThemeMode>(
          valueListenable: modeNotifier,
          builder: (context, mode, _) => ValueListenableBuilder<Locale?>(
            valueListenable: localeNotifier,
            builder: (context, value, _) => _materialApp(value ?? locale, mode),
          ),
        );
      } else {
        app = ValueListenableBuilder<ThemeMode>(
          valueListenable: modeNotifier,
          builder: (context, mode, _) => _materialApp(locale, mode),
        );
      }
    }
    return app;
  }

  Widget _materialApp(Locale? localeOverride, ThemeMode mode) =>
      MaterialApp.router(
        title: 'Devmate',
        debugShowCheckedModeBanner: false,
        locale: localeOverride,
        theme: devmateLightTheme(),
        darkTheme: devmateTheme(),
        themeMode: mode,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      );
}
