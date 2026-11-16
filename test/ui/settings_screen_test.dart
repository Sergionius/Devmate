import 'package:devmate/data/app_preferences.dart';
import 'package:devmate/data/llm_settings.dart';

import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/router.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/platform_ui.dart';
import 'package:devmate/ui/settings_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../support/memory_secure_storage.dart';

class _FailingProgress implements ProgressRepository {
  @override
  Future<Map<String, int>> load() async => {};

  @override
  Future<void> save(Map<String, int> values) async {
    throw StateError('storage unavailable');
  }
}

class _MemoryProgress implements ProgressRepository {
  Map<String, int> scores = {};

  @override
  Future<Map<String, int>> load() async => {...scores};

  @override
  Future<void> save(Map<String, int> values) async {
    scores = {...values};
  }
}

MaterialApp _routerApp(GoRouter router) => MaterialApp.router(
  theme: devmateTheme(),
  routerConfig: router,
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
);

void main() {
  tearDown(() {
    debugDevmateSimulateWeb = false;
  });

  /// Runs [body] with the given target platform, resetting the override
  /// inside the test body as required by the framework invariants.
  Future<void> withPlatform(
    WidgetTester tester,
    TargetPlatform? platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpAndSettle();
    }
  }

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
        home: DataSettingsScreen(
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

  testWidgets('provider selection saves API-key settings', (tester) async {
    final repo = LlmSettingsRepository(storage: MemorySecureStorage());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AiSettingsScreen(settingsRepository: repo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<LlmPreset>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OpenAI').last);
    await tester.enterText(find.byType(TextField).last, 'test-key');
    await tester.scrollUntilVisible(
      find.text('Save'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final loaded = await repo.load();
    expect(loaded.baseUrl, 'https://api.openai.com/v1');
    expect(loaded.apiKey, 'test-key');
    expect(find.text('ChatGPT Codex (subscription)'), findsNothing);
  });

  testWidgets('iOS provider uses an action sheet and applies the preset', (
    tester,
  ) async {
    await withPlatform(tester, TargetPlatform.iOS, () async {
      final repo = LlmSettingsRepository(storage: MemorySecureStorage());
      await tester.pumpWidget(
        MaterialApp(
          theme: devmateTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiSettingsScreen(settingsRepository: repo),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<LlmPreset>), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Provider'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('OpenAI').last);
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      final baseUrlField = tester.widget<TextField>(
        find.byType(TextField).first,
      );
      expect(baseUrlField.controller!.text, 'https://api.openai.com/v1');
      expect(baseUrlField.decoration!.labelText, isNull);
      expect(baseUrlField.decoration!.hintText, 'Base URL');
      expect(find.byType(CupertinoSlidingSegmentedControl<bool>), findsNothing);
      expect(find.byType(CupertinoTextField), findsNothing);
      final modelField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Model'),
      );
      expect(modelField.decoration!.labelText, isNull);
      expect(modelField.decoration!.hintText, 'Model');
      final apiKeyField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'API key'),
      );
      expect(apiKeyField.decoration!.labelText, isNull);
      expect(apiKeyField.decoration!.hintText, 'API key');
      expect(modelField.controller!.text, 'gpt-4.1-mini');
    });
  });

  testWidgets('switching language applies the locale and persists the choice', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    final appPreferences = AppPreferencesRepository();
    final appLocale = ValueNotifier<Locale?>(null);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
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

  testWidgets('iOS language uses an action sheet and persists selection', (
    tester,
  ) async {
    await withPlatform(tester, TargetPlatform.iOS, () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final preferences = AppPreferencesRepository();
      final locale = ValueNotifier<Locale?>(null);
      await tester.pumpWidget(
        MaterialApp(
          theme: devmateTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(appLocale: locale, appPreferences: preferences),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<AppLanguage>), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'App language'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();
      expect(locale.value, const Locale('en'));
      expect(await preferences.loadLanguage(), AppLanguage.english);
    });
  });

  testWidgets('iOS theme uses an action sheet and applies instantly', (
    tester,
  ) async {
    await withPlatform(tester, TargetPlatform.iOS, () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      final preferences = AppPreferencesRepository();
      final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
      await tester.pumpWidget(
        ValueListenableBuilder<ThemeMode>(
          valueListenable: themeMode,
          builder: (context, mode, _) => MaterialApp(
            theme: devmateLightTheme(),
            darkTheme: devmateTheme(),
            themeMode: mode,
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(
              themeMode: themeMode,
              appPreferences: preferences,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(DropdownButtonFormField<AppThemePreference>),
        findsNothing,
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Appearance'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();
      expect(themeMode.value, ThemeMode.dark);
      expect(await preferences.loadTheme(), AppThemePreference.dark);
      final context = tester.element(find.byType(Scaffold).first);
      expect(Theme.of(context).brightness, Brightness.dark);
    });
  });

  testWidgets('theme dropdown on Android applies and persists', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    final preferences = AppPreferencesRepository();
    final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
    await tester.pumpWidget(
      ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) => MaterialApp(
          theme: devmateLightTheme(),
          darkTheme: devmateTheme(),
          themeMode: mode,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(
            themeMode: themeMode,
            appPreferences: preferences,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<AppThemePreference>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();
    expect(themeMode.value, ThemeMode.light);
    expect(await preferences.loadTheme(), AppThemePreference.light);
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('settings overview links to the AI and data sections', (
    tester,
  ) async {
    final model = TrainingViewModel(
      _MemoryProgress(),
      catalogRepository: TopicCatalog(),
    )..load();
    final router = createRouter(
      model,
      LlmSettingsRepository(storage: MemorySecureStorage()),
      TopicCatalog(),
      appLocale: ValueNotifier<Locale?>(null),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerApp(router));
    await tester.pumpAndSettle();

    // The home gear opens the settings overview, not a concrete section.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');
    expect(find.text('App language'), findsOneWidget);

    await tester.tap(find.text('AI provider'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings/ai');
    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings');

    await tester.tap(find.text('Questions and data'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings/data');
    expect(find.text('Import JSON'), findsOneWidget);
  });

  testWidgets(
    'iOS import actions stay stacked and the sheet fills bottom inset',
    (tester) async {
      await withPlatform(tester, TargetPlatform.iOS, () async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.view.viewPadding = const FakeViewPadding(bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpWidget(
          MaterialApp(
            theme: devmateTheme(),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: DataSettingsScreen(
              settingsRepository: LlmSettingsRepository(
                storage: MemorySecureStorage(),
              ),
              catalog: TopicCatalog(),
              viewModel: TrainingViewModel(_MemoryProgress()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Import JSON'));
        await tester.pumpAndSettle();
        final add = find.widgetWithText(FilledButton, 'Add');
        final replace = find.widgetWithText(OutlinedButton, 'Replace all');
        final cancel = find.widgetWithText(TextButton, 'Cancel');
        expect(add, findsOneWidget);
        expect(replace, findsOneWidget);
        expect(cancel, findsOneWidget);
        expect(tester.getTopLeft(add).dx, tester.getTopLeft(replace).dx);
        expect(tester.getTopLeft(replace).dx, tester.getTopLeft(cancel).dx);
        expect(
          tester.getBottomLeft(add).dy,
          lessThan(tester.getTopLeft(replace).dy),
        );
        expect(
          tester.getBottomLeft(replace).dy,
          lessThan(tester.getTopLeft(cancel).dy),
        );
        final sheet = find
            .ancestor(of: add, matching: find.byType(Material))
            .first;
        expect(tester.getBottomLeft(sheet).dy, 844);
        expect(tester.takeException(), isNull);
      });
    },
  );

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
        home: DataSettingsScreen(
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
        home: DataSettingsScreen(
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
        home: DataSettingsScreen(
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

  testWidgets('failed iOS reset never emits a success haptic', (tester) async {
    await withPlatform(tester, TargetPlatform.iOS, () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(SystemChannels.platform.name, (
        data,
      ) async {
        final call = const JSONMethodCodec().decodeMethodCall(data!);
        if (call.method == 'HapticFeedback.vibrate') calls.add(call);
        return null;
      });
      addTearDown(
        () =>
            messenger.setMockMessageHandler(SystemChannels.platform.name, null),
      );
      final catalog = TopicCatalog();
      final model = TrainingViewModel(_FailingProgress());
      await model.load();
      await tester.pumpWidget(
        MaterialApp(
          theme: devmateTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DataSettingsScreen(
            settingsRepository: LlmSettingsRepository(
              storage: MemorySecureStorage(),
            ),
            catalog: catalog,
            viewModel: model,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.text('Reset progress only');
      await tester.scrollUntilVisible(
        button,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset progress only').last);
      await tester.pumpAndSettle();
      expect(find.text('Failed to reset progress'), findsOneWidget);
      expect(calls, isEmpty);
    });
  });

  testWidgets('reset confirmation on iOS uses the Cupertino contract', (
    tester,
  ) async {
    await withPlatform(tester, TargetPlatform.iOS, () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMessageHandler(SystemChannels.platform.name, (
        data,
      ) async {
        final call = const JSONMethodCodec().decodeMethodCall(data!);
        if (call.method == 'HapticFeedback.vibrate') calls.add(call);
        return null;
      });
      addTearDown(
        () =>
            messenger.setMockMessageHandler(SystemChannels.platform.name, null),
      );
      final settings = LlmSettingsRepository(storage: MemorySecureStorage());
      final catalog = TopicCatalog();
      final topic = await catalog.addUserTopic('Docker', 'Containers', [
        ('What is an image?', 'A template.'),
      ]);
      final model = TrainingViewModel(
        _MemoryProgress(),
        catalogRepository: catalog,
      )..load();
      await model.record(topic.questions.single, knewAnswer: true);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DataSettingsScreen(
            settingsRepository: settings,
            catalog: catalog,
            viewModel: model,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.text('Reset progress only');
      await tester.scrollUntilVisible(
        button,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button.first);
      await tester.pumpAndSettle();
      // Platform contract: Cupertino alert, no Material dialog.
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      // Cancel keeps the recorded progress.
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(model.points, 10);
      expect(calls, isEmpty);

      // Confirm resets it.
      await tester.tap(button.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset progress only').last);
      await tester.pumpAndSettle();
      expect(model.points, 0);
      expect(calls.single.arguments, 'HapticFeedbackType.successNotification');
    });
  });

  testWidgets(
    'reset-all confirmation on web is a capped dialog with safe focus',
    (tester) async {
      debugDevmateSimulateWeb = true;
      final settings = LlmSettingsRepository(storage: MemorySecureStorage());
      final catalog = TopicCatalog();
      final topic = await catalog.addUserTopic('Docker', 'Containers', [
        ('What is an image?', 'A template.'),
      ]);
      final model = TrainingViewModel(
        _MemoryProgress(),
        catalogRepository: catalog,
      )..load();
      await model.record(topic.questions.single, knewAnswer: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: devmateTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DataSettingsScreen(
            settingsRepository: settings,
            catalog: catalog,
            viewModel: model,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.text('Reset everything');
      await tester.scrollUntilVisible(
        button,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(button.first);
      await tester.pumpAndSettle();

      // Wide layout: themed dialog capped to a reasonable width.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox && widget.constraints.maxWidth == 600,
        ),
        findsOneWidget,
      );
      // For a destructive confirm the keyboard focus lands on Cancel, so
      // pressing Enter performs the safer action on web.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(model.points, 10);
    },
  );

  testWidgets('disabling AI hides the provider section and persists', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    final appPreferences = AppPreferencesRepository();
    final aiDisabled = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          appPreferences: appPreferences,
          aiDisabled: aiDisabled,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Disable AI'), findsOneWidget);
    expect(find.text('AI provider'), findsOneWidget);
    expect(aiDisabled.value, isFalse);

    await tester.tap(find.text('Disable AI'));
    await tester.pumpAndSettle();

    expect(aiDisabled.value, isTrue);
    expect(await appPreferences.loadAiDisabled(), isTrue);
    expect(find.text('AI provider'), findsNothing);
    expect(find.text('Questions and data'), findsOneWidget);

    await tester.tap(find.text('Disable AI'));
    await tester.pumpAndSettle();
    expect(aiDisabled.value, isFalse);
    expect(find.text('AI provider'), findsOneWidget);
  });

  testWidgets('a saved "AI disabled" choice restores on open', (tester) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    final appPreferences = AppPreferencesRepository();
    await appPreferences.saveAiDisabled(true);
    final aiDisabled = ValueNotifier<bool>(false);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          appPreferences: appPreferences,
          aiDisabled: aiDisabled,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(aiDisabled.value, isTrue);
    expect(find.text('AI provider'), findsNothing);
  });
}
