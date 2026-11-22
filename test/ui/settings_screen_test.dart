import 'dart:async';

import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:devmate/data/app_preferences.dart';
import 'package:devmate/data/data_transfer.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/domain/question.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/router.dart';
import 'package:devmate/ui/ai_settings_screen.dart';
import 'package:devmate/ui/data_settings_screen.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/platform_ui.dart';
import 'package:devmate/ui/settings_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
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
      await tester.tap(find.widgetWithText(DevmateSelectionField, 'Provider'));
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
    );

    unawaited(model.load());
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
      // The backup section above made the button land at the very edge of
      // the viewport; make sure it is fully on screen before tapping.
      await tester.ensureVisible(button.first);
      await tester.pumpAndSettle();
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
      );

      unawaited(model.load());
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
      );

      unawaited(model.load());
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

  group('file transfer and backup', () {
    late LlmSettingsRepository settings;
    late TopicCatalog catalog;
    late _MemoryProgress progress;
    late TrainingViewModel model;
    late AppPreferencesRepository appPreferences;
    late InterviewTopic docker;

    Future<void> pumpScreen(
      WidgetTester tester, {
      Future<String?> Function()? pickJsonFile,
      void Function(String fileName, String content)? onShare,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DataSettingsScreen(
            settingsRepository: settings,
            catalog: catalog,
            viewModel: model,
            appPreferences: appPreferences,
            pickJsonFile: pickJsonFile ?? () async => null,
            shareJsonFile: (fileName, content) async =>
                onShare?.call(fileName, content),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({});
      settings = LlmSettingsRepository(storage: MemorySecureStorage());
      await settings.save(
        const LlmSettings(
          baseUrl: 'https://current.example/v1',
          model: 'current-model',
          apiKey: 'secret-key',
        ),
      );
      catalog = TopicCatalog();
      docker = await catalog.addUserTopic('Docker', 'Containers', [
        ('What is an image?', 'A template.'),
      ]);
      progress = _MemoryProgress();
      model = TrainingViewModel(progress, catalogRepository: catalog);
      await model.load();
      await model.record(docker.questions.single, knewAnswer: true);
      appPreferences = AppPreferencesRepository();
      await appPreferences.saveTheme(AppThemePreference.dark);
    });

    /// scrollUntilVisible stops once a lazy ListView child is built, which
    /// can leave it just off-screen; ensureVisible brings it fully into view.
    Future<void> scrollTo(WidgetTester tester, String label) async {
      final finder = find.text(label);
      await tester.scrollUntilVisible(
        finder,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    /// The apply path runs through several awaits after the dialog closes;
    /// pump until the expected condition appears instead of one settle.
    Future<void> pumpUntil(
      WidgetTester tester,
      bool Function() condition,
    ) async {
      for (var i = 0; i < 40 && !condition(); i++) {
        // Escaping FakeAsync lets the dialog's async apply path actually run.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('export to file shares the catalog JSON', (tester) async {
      final shared = <String>[];
      await pumpScreen(
        tester,
        onShare: (fileName, content) => shared.add('$fileName|$content'),
      );
      await scrollTo(tester, 'Export to file');
      await tester.tap(find.text('Export to file'));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      final parts = shared.single.split('|');
      expect(parts.first, startsWith('devmate-questions-'));
      final exported = jsonDecode(parts.last) as Map<String, dynamic>;
      expect(exported['version'], 1);
      expect(
        (exported['topics'] as List).where(
          (topic) => (topic as Map<String, dynamic>)['title'] == 'Docker',
        ),
        isNotEmpty,
      );
    });

    testWidgets('export backup includes progress and never the API key', (
      tester,
    ) async {
      final shared = <String>[];
      await pumpScreen(
        tester,
        onShare: (fileName, content) => shared.add('$fileName|$content'),
      );
      await scrollTo(tester, 'Export everything');
      await tester.tap(find.text('Export everything'));
      await tester.pumpAndSettle();

      expect(shared, hasLength(1));
      final parts = shared.single.split('|');
      expect(parts.first, startsWith('devmate-backup-'));
      final backup = DevmateBackup.parse(parts.last);
      expect(backup.scores[docker.questions.single.id], 10);
      expect(jsonEncode(backup.encode()), isNot(contains('secret-key')));
      final ai = backup.ai!;
      expect(ai['baseUrl'], 'https://current.example/v1');
      expect(ai['model'], 'current-model');
      expect(ai.containsKey('apiKey'), isFalse);
      expect(backup.preferences!['theme'], 'dark');
    });

    testWidgets('backup import replace restores IDs, progress and settings', (
      tester,
    ) async {
      final backup = DevmateBackup(
        catalog: {
          'version': 1,
          'topics': [
            {
              'id': 'topic-1',
              'title': 'Git',
              'description': 'VCS',
              'questions': [
                {
                  'id': 'q-rebase',
                  'prompt': 'What is a rebase?',
                  'answer': 'Rewriting history.',
                },
              ],
            },
          ],
        },
        scores: {'q-rebase': 10, 'q-unknown': 5},
        preferences: {'theme': 'light', 'aiDisabled': true},
        ai: {'baseUrl': 'https://backup.example/v1', 'model': 'backup-model'},
      );
      await pumpScreen(tester, pickJsonFile: () async => backup.encode());
      await scrollTo(tester, 'Import backup');
      await tester.tap(find.text('Import backup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Topics in file: 1'), findsOneWidget);
      await tester.tap(find.text('Replace everything'));
      await pumpUntil(tester, () => catalog.topicById('topic-1') != null);

      final git = catalog.topicById('topic-1');
      expect(git, isNotNull);
      expect(git!.questions.single.id, 'q-rebase');
      expect(model.scores, {'q-rebase': 10});
      expect(progress.scores, {'q-rebase': 10});
      expect(await appPreferences.loadTheme(), AppThemePreference.light);
      expect(await appPreferences.loadAiDisabled(), isTrue);
      final restoredAi = await settings.load();
      expect(restoredAi.baseUrl, 'https://backup.example/v1');
      expect(restoredAi.model, 'backup-model');
      expect(restoredAi.apiKey, 'secret-key');
      expect(find.textContaining('Backup restored'), findsOneWidget);
    });

    testWidgets('backup import merge keeps the better score per question', (
      tester,
    ) async {
      final backup = DevmateBackup(
        catalog: {
          'version': 1,
          'topics': [
            {
              'id': 'topic-2',
              'title': 'HTTP',
              'description': 'Protocol',
              'questions': [
                {
                  'id': 'q-status',
                  'prompt': 'What is 404?',
                  'answer': 'Not found.',
                },
              ],
            },
          ],
        },
        scores: {docker.questions.single.id: 5, 'q-status': 10},
      );
      await pumpScreen(tester, pickJsonFile: () async => backup.encode());
      await scrollTo(tester, 'Import backup');
      await tester.tap(find.text('Import backup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Merge'));
      // The notice is the last step of the apply chain — waiting for it
      // proves the whole merge finished.
      await pumpUntil(
        tester,
        () => find
            .textContaining('Topics added. Existing questions')
            .evaluate()
            .isNotEmpty,
      );

      final http = catalog.topics.singleWhere((topic) => topic.title == 'HTTP');
      expect(http.questions.single.prompt, 'What is 404?');
      // Merge keeps IDs fresh for imported questions, so their backup
      // progress is not applied; existing questions keep the best score.
      expect(model.scores[docker.questions.single.id], 10);
      expect(model.scores.containsKey(http.questions.single.id), isFalse);
      final ai = await settings.load();
      expect(ai.baseUrl, 'https://current.example/v1');
      expect(await appPreferences.loadTheme(), AppThemePreference.dark);
      expect(
        find.textContaining('Topics added. Existing questions'),
        findsOneWidget,
      );
    });

    testWidgets('import from file prefills the dialog and appends', (
      tester,
    ) async {
      const incoming =
          '{"version":1,"topics":[{"title":"Kotlin","description":"Lang","questions":[{"prompt":"suspend?","answer":"Coroutines."}]}]}';
      await pumpScreen(tester, pickJsonFile: () async => incoming);
      await scrollTo(tester, 'Import from file');
      await tester.tap(find.text('Import from file'));
      await tester.pumpAndSettle();

      final controller = tester
          .widget<TextField>(find.byType(TextField).first)
          .controller;
      expect(controller!.text, incoming);
      await tester.tap(find.text('Add'));
      await pumpUntil(
        tester,
        () => catalog.topics.any((topic) => topic.title == 'Kotlin'),
      );

      expect(catalog.topics.any((topic) => topic.title == 'Kotlin'), isTrue);
      expect(model.points, 10);
    });

    testWidgets('a foreign file shows a clear error and changes nothing', (
      tester,
    ) async {
      await pumpScreen(tester, pickJsonFile: () async => '{"hello": "world"}');
      await scrollTo(tester, 'Import backup');
      await tester.tap(find.text('Import backup'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Not a Devmate backup file'), findsOneWidget);
      expect(catalog.topicById('topic-1'), isNull);
      expect(model.points, 10);
    });

    testWidgets('a broken catalog inside a valid backup shows details', (
      tester,
    ) async {
      final broken = jsonEncode({
        'format': 'devmate-backup',
        'version': 1,
        'catalog': {
          'version': 1,
          'topics': [
            {'id': '', 'title': 'Git', 'description': '', 'questions': []},
          ],
        },
      });
      await pumpScreen(tester, pickJsonFile: () async => broken);
      await scrollTo(tester, 'Import backup');
      await tester.tap(find.text('Import backup'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid topic'), findsOneWidget);
      // Nothing changed: built-ins plus the user topic from setUp remain.
      expect(catalog.topics.length, 11);
      expect(catalog.topics.where((topic) => topic.title == 'Git'), isEmpty);
      expect(model.points, 10);
    });
  });
}
