import 'package:material_ui/material_ui.dart';
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

  final llmSettings = LlmSettingsRepository();
  final appPreferences = AppPreferencesRepository();
  AppLanguage savedLanguage = AppLanguage.system;
  try {
    savedLanguage = await appPreferences.loadLanguage();
  } catch (error) {
    debugPrint('main: failed to read saved language: $error');
  }
  bool aiDisabled = false;
  try {
    aiDisabled = await appPreferences.loadAiDisabled();
  } catch (error) {
    debugPrint('main: failed to read AI-disabled setting: $error');
  }
  AppThemePreference savedTheme = AppThemePreference.dark;
  try {
    savedTheme = await appPreferences.loadTheme();
  } catch (error) {
    debugPrint('main: failed to read saved theme: $error');
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

  final ValueNotifier<Locale?>? appLocale;

  final ValueNotifier<bool>? aiDisabled;

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
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      );
}
