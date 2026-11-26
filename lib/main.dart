import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_preferences.dart';
import 'data/chat_history_repository.dart';
import 'data/llm_settings.dart';
import 'data/progress_repository.dart';
import 'data/question_catalog.dart';
import 'data/topic_catalog.dart';
import 'l10n/app_localizations.dart';
import 'platform/app_environment.dart';
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
  final environment = createAppEnvironment();
  runApp(
    DevmateApp(
      environment: environment,
      viewModel: _startTraining(catalog),
      llmSettings: llmSettings,
      catalog: catalog,
      appLocale: ValueNotifier<Locale?>(savedLanguage.locale),
      aiDisabled: ValueNotifier<bool>(aiDisabled),
      themeMode: ValueNotifier<ThemeMode>(savedTheme.mode),
      appPreferences: appPreferences,
      chatHistory: ChatHistoryRepository(),
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => environment.ready());
}

TrainingViewModel _startTraining(TopicCatalog catalog) {
  final viewModel = TrainingViewModel(
    LocalProgressRepository(SharedPreferencesAsync()),
    catalogRepository: catalog,
  );
  unawaited(viewModel.load());
  return viewModel;
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
    this.chatHistory,
    this.environment,
  }) : router = createRouter(
         viewModel,
         llmSettings,
         catalog,
         appLocale: appLocale,
         aiDisabled: aiDisabled,
         themeMode: themeMode,
         appPreferences: appPreferences,
         chatHistory: chatHistory,
       ) {
    environment?.attachRouter(router);
  }

  final GoRouter router;
  final AppEnvironment? environment;
  final Locale? locale;

  final ValueNotifier<Locale?>? appLocale;

  final ValueNotifier<bool>? aiDisabled;

  final ValueNotifier<ThemeMode>? themeMode;

  final AppPreferencesRepository? appPreferences;
  final ChatHistoryRepository? chatHistory;

  @override
  Widget build(BuildContext context) {
    final hostTheme = environment?.preferredTheme;
    if (hostTheme == null) return _buildApp(null);
    return ValueListenableBuilder<ThemeMode?>(
      valueListenable: hostTheme,
      builder: (context, mode, _) => _buildApp(mode),
    );
  }

  Widget _buildApp(ThemeMode? hostMode) {
    final localeNotifier = appLocale;
    final modeNotifier = themeMode;
    ThemeMode initialMode() =>
        effectiveThemeMode(modeNotifier?.value ?? ThemeMode.dark, hostMode);

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
            builder: (context, value, _) => _materialApp(
              value ?? locale,
              effectiveThemeMode(mode, hostMode),
            ),
          ),
        );
      } else {
        app = ValueListenableBuilder<ThemeMode>(
          valueListenable: modeNotifier,
          builder: (context, mode, _) =>
              _materialApp(locale, effectiveThemeMode(mode, hostMode)),
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
