import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/llm_settings.dart';
import 'data/progress_repository.dart';
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
  runApp(
    DevmateApp(
      viewModel: TrainingViewModel(
        LocalProgressRepository(SharedPreferencesAsync()),
      )..load(),
      llmSettings: llmSettings,
    ),
  );
}

class DevmateApp extends StatelessWidget {
  DevmateApp({
    super.key,
    required TrainingViewModel viewModel,
    required LlmSettingsRepository llmSettings,
  }) : router = createRouter(viewModel, llmSettings);

  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Devmate',
    debugShowCheckedModeBanner: false,
    theme: devmateTheme(),
    routerConfig: router,
  );
}
