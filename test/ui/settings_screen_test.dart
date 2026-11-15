import 'package:devmate/data/app_preferences.dart';
import 'package:devmate/data/llm_settings.dart';

import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/settings_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/memory_secure_storage.dart';

class _MemoryProgress implements ProgressRepository {
  Map<String, int> scores = {};

  @override
  Future<Map<String, int>> load() async => {...scores};

  @override
  Future<void> save(Map<String, int> values) async {
    scores = {...values};
  }
}

void main() {
  testWidgets('reset progress only keeps topics and AI settings', (
    tester,
  ) async {
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    const aiConfig = LlmSettings(
      baseUrl: 'https://example.org',
      model: 'test-model',
      apiKey: 'secret',
    );
    await settings.save(aiConfig);
    final catalog = TopicCatalog();
    final topic = await catalog.addUserTopic('Docker', 'Containers', [
      ('What is an image?', 'A template.'),
    ]);
    final progress = _MemoryProgress();
    final model = TrainingViewModel(progress, catalogRepository: catalog);
    await model.load();
    await model.record(topic.questions.single, knewAnswer: true);
    expect(model.points, 10);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          settingsRepository: settings,
          catalog: catalog,
          viewModel: model,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Reset progress only');
    await tester.scrollUntilVisible(
      button,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button.first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Questions, topics and AI settings will be kept'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(model.points, 10);
    await tester.tap(button.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset progress only').last);
    await tester.pumpAndSettle();
    expect(model.completed, 0);
    expect(model.points, 0);
    expect(progress.scores, isEmpty);
    expect(
      catalog.topicById(topic.id)!.questions.single.prompt,
      'What is an image?',
    );
    final saved = await settings.load();
    expect(saved.toMap(), aiConfig.toMap());
  });

  testWidgets(
    'choosing codex preset persists codexDeviceCode auth mode on save',
    (tester) async {
      final storage = MemorySecureStorage();
      final repo = LlmSettingsRepository(storage: storage);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(settingsRepository: repo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<LlmPreset>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ChatGPT Codex (subscription)').last);

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The language dropdown pushed the form down: the button is beyond
      // the lazy ListView cache extent — drag until visible. pumpAndSettle
      // is not an option here: the Codex login card animates forever.
      await tester.scrollUntilVisible(
        find.text('Save'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final loaded = await repo.load();
      expect(loaded.authMode, LlmAuthMode.codexDeviceCode);
      expect(loaded.baseUrl, 'https://chatgpt.com/backend-api/codex');
      expect(loaded.model, 'gpt-6-luna');
    },
  );

  testWidgets('switching language applies the locale and persists the choice', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    const aiConfig = LlmSettings(
      baseUrl: 'https://example.org',
      model: 'test-model',
      apiKey: 'secret',
    );
    await settings.save(aiConfig);
    final appPreferences = AppPreferencesRepository();
    final appLocale = ValueNotifier<Locale?>(null);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          settingsRepository: settings,
          appLocale: appLocale,
          appPreferences: appPreferences,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<AppLanguage>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(appLocale.value, const Locale('en'));
    expect(await appPreferences.loadLanguage(), AppLanguage.english);
  });

  testWidgets('import dialog Add mode appends questions and keeps progress', (
    tester,
  ) async {
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    final catalog = TopicCatalog();
    final topic = await catalog.addUserTopic('Docker', 'Containers', [
      ('What is an image?', 'A template.'),
    ]);
    final progress = _MemoryProgress();
    final model = TrainingViewModel(progress, catalogRepository: catalog);
    await model.load();
    await model.record(topic.questions.single, knewAnswer: true);
    expect(model.points, 10);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          settingsRepository: settings,
          catalog: catalog,
          viewModel: model,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final importButton = find.text('Import JSON');
    await tester.scrollUntilVisible(
      importButton,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(importButton);
    await tester.pumpAndSettle();

    // Both modes and cancel are offered in the dialog.
    expect(find.widgetWithText(OutlinedButton, 'Add'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Replace all'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(
      dialogField,
      '{"version":1,"topics":[{"title":"Docker","description":"",'
      '"questions":[{"prompt":"What is a layer?","answer":"A step."}]}]}',
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Questions added; existing topics and progress'),
      findsOneWidget,
    );
    final docker = catalog.topics.where((t) => t.title == 'Docker').single;
    expect(docker.questions, hasLength(2));
    expect(docker.questions.last.prompt, 'What is a layer?');
    // Append keeps the recorded progress untouched.
    expect(model.points, 10);
    expect(progress.scores, isNotEmpty);
  });

  testWidgets('import dialog Replace all resets catalog and progress', (
    tester,
  ) async {
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    final catalog = TopicCatalog();
    final topic = await catalog.addUserTopic('Docker', 'Containers', [
      ('What is an image?', 'A template.'),
    ]);
    final progress = _MemoryProgress();
    final model = TrainingViewModel(progress, catalogRepository: catalog);
    await model.load();
    await model.record(topic.questions.single, knewAnswer: true);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          settingsRepository: settings,
          catalog: catalog,
          viewModel: model,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final importButton = find.text('Import JSON');
    await tester.scrollUntilVisible(
      importButton,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(importButton);
    await tester.pumpAndSettle();

    final dialogField = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(
      dialogField,
      '{"version":1,"topics":[{"title":"Fresh Topic","description":"",'
      '"questions":[{"prompt":"Only question?","answer":"Yes."}]}]}',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Replace all'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Catalog replaced from JSON, progress reset'),
      findsOneWidget,
    );
    // Full replace behaves like the former import: user topics are swapped
    // and all recorded progress is cleared.
    expect(catalog.topics.map((t) => t.title), ['Fresh Topic']);
    expect(model.points, 0);
    expect(progress.scores, isEmpty);
  });

  testWidgets('agent instruction section shows localized Share button', (
    tester,
  ) async {
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    final catalog = TopicCatalog();
    final progress = _MemoryProgress();
    final model = TrainingViewModel(progress, catalogRepository: catalog);
    await model.load();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          settingsRepository: settings,
          catalog: catalog,
          viewModel: model,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final instruction = find.textContaining('Agent instruction:');
    await tester.scrollUntilVisible(
      instruction,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    // Localized share affordance next to the selectable instruction text;
    // the real system share sheet is never opened in the test.
    final shareButton = find.byTooltip('Share instruction');
    expect(shareButton, findsOneWidget);
    final row = find
        .ancestor(of: shareButton, matching: find.byType(Row))
        .first;
    expect(find.descendant(of: row, matching: instruction), findsOneWidget);
  });
}
