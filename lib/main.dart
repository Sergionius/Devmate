import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/progress_repository.dart';
import 'router.dart';
import 'ui/design_system.dart';
import 'ui/training_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    DevmateApp(
      viewModel: TrainingViewModel(
        LocalProgressRepository(SharedPreferencesAsync()),
      )..load(),
    ),
  );
}

class DevmateApp extends StatelessWidget {
  DevmateApp({super.key, required TrainingViewModel viewModel})
    : router = createRouter(viewModel);

  final GoRouter router;

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Devmate',
    debugShowCheckedModeBanner: false,
    theme: devmateTheme(),
    routerConfig: router,
  );
}
