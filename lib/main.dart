import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/app_localizations.dart';
import 'data/llm_settings.dart';
import 'data/progress_repository.dart';
import 'data/topic_catalog.dart';
import 'router.dart';
import 'ui/design_system.dart';
import 'ui/training_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env is optional: missing or empty file → start with empty settings.
  // dotenv.load() throws EmptyEnvFileError on an empty file, and the fallback
  // needs isOptional:true, otherwise the error escapes main() and the app
  // freezes on the splash screen.
  try {
    await dotenv.load(fileName: 'assets/config/.env');
  } catch (_) {
    dotenv.loadFromString(envString: '', isOptional: true);
  }
  final llmSettings = LlmSettingsRepository();
  final catalog = TopicCatalog(
    userTopicsRepository: LocalUserTopicsRepository(SharedPreferencesAsync()),
  );
  // Загружаем каталог ДО viewModel: чистка прогресса по knownQuestionIds
  // должна видеть пользовательские темы, иначе их прогресс теряется.
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
  }) : router = createRouter(viewModel, llmSettings, catalog);

  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Devmate',
    debugShowCheckedModeBanner: false,
    theme: devmateTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}
