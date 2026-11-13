import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/progress_repository.dart';
import 'ui/design_system.dart';
import 'ui/home_screen.dart';
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
  const DevmateApp({super.key, required this.viewModel});

  final TrainingViewModel viewModel;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Devmate',
    debugShowCheckedModeBanner: false,
    theme: devmateTheme(),
    home: HomeScreen(viewModel: viewModel),
  );
}
