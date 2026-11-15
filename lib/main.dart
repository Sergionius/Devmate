import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
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
  final catalog = TopicCatalog(
    userTopicsRepository: LocalUserTopicsRepository(SharedPreferencesAsync()),
    baseTopics: questionCatalogFor(
      WidgetsBinding.instance.platformDispatcher.locale.languageCode,
    ),
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
  }) : router = createRouter(viewModel, llmSettings, catalog);

  final GoRouter router;
  final Locale? locale;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Devmate',
    debugShowCheckedModeBanner: false,
    locale: locale,
    theme: devmateTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}
