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
    this.appPreferences,
  }) : router = createRouter(
         viewModel,
         llmSettings,
         catalog,
         appLocale: appLocale,
         appPreferences: appPreferences,
       );

  final GoRouter router;
  final Locale? locale;

  /// Живой выбор языка из настроек; `null` в значении — язык системы.
  final ValueNotifier<Locale?>? appLocale;

  final AppPreferencesRepository? appPreferences;

  @override
  Widget build(BuildContext context) {
    Widget app = _materialApp(locale);
    final notifier = appLocale;
    if (notifier != null) {
      app = ValueListenableBuilder<Locale?>(
        valueListenable: notifier,
        builder: (context, value, _) => _materialApp(value ?? locale),
      );
    }
    return app;
  }

  Widget _materialApp(Locale? localeOverride) => MaterialApp.router(
    title: 'Devmate',
    debugShowCheckedModeBanner: false,
    locale: localeOverride,
    theme: devmateTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}
