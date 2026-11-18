import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/question_catalog.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/main.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class MemoryProgressRepository implements ProgressRepository {
  Map<String, int> scores = {};

  @override
  Future<Map<String, int>> load() async => {...scores};

  @override
  Future<void> save(Map<String, int> scores) async {
    this.scores = {...scores};
  }
}

void main() {
  testWidgets('practice deep link for an empty topic shows not found', (
    tester,
  ) async {
    final model = TrainingViewModel(MemoryProgressRepository());
    await model.load();
    final catalog = TopicCatalog(baseTopics: []);
    final topic = await catalog.addUserTopic('Empty topic', '', []);
    final app = DevmateApp(
      viewModel: model,
      llmSettings: LlmSettingsRepository(),
      catalog: catalog,
      locale: const Locale('en'),
    );
    await tester.pumpWidget(app);
    app.router.go('/topic/${topic.id}/practice/0');
    await tester.pumpAndSettle();
    expect(find.text('This page does not exist.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adds a topic manually as the last tile with AI disabled', (
    tester,
  ) async {
    final model = TrainingViewModel(MemoryProgressRepository());
    await model.load();
    final catalog = TopicCatalog(baseTopics: questionCatalogFor('en'));
    await tester.pumpWidget(
      DevmateApp(
        viewModel: model,
        llmSettings: LlmSettingsRepository(),
        catalog: catalog,
        locale: const Locale('en'),
        aiDisabled: ValueNotifier(true),
      ),
    );

    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    expect(grid.delegate.estimatedChildCount, catalog.topics.length + 1);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Add topic'),
      300,
      scrollable: scrollable,
    );
    expect(find.text('Add topic'), findsOneWidget);
    await tester.tap(find.text('Add topic'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add topic').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter a topic title.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'My own topic');
    await tester.enterText(find.byType(TextField).last, 'Practice without AI');
    await tester.tap(find.text('Add topic').last);
    await tester.pumpAndSettle();

    expect(catalog.topics.last.title, 'My own topic');
    expect(catalog.topics.last.questions, isEmpty);
    expect(find.text('Edit topic'), findsOneWidget);
    await tester.tap(find.text('Add question'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'A sample answer');
    await tester.enterText(
      find.byType(TextField).at(find.byType(TextField).evaluate().length - 2),
      'A sample question',
    );
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(catalog.topics.last.questions.single.prompt, 'A sample question');
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows topics and completes the self-assessment flow', (
    tester,
  ) async {
    final repository = MemoryProgressRepository();
    final model = TrainingViewModel(repository);
    await model.load();
    await tester.pumpWidget(
      DevmateApp(
        viewModel: model,
        llmSettings: LlmSettingsRepository(),
        catalog: TopicCatalog(baseTopics: questionCatalogFor('en')),
        locale: const Locale('en'),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Pick a topic'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Pick a topic'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Frontend'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Frontend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frontend'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Continue training'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Continue training'));
    await tester.pumpAndSettle();

    expect(find.text('Compare with reference'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('answer-field')), 'My answer');
    await tester.pump();
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Compare with reference'));
    await tester.tap(find.text('Compare with reference'));
    await tester.pumpAndSettle();
    expect(find.text('REFERENCE ANSWER', skipOffstage: false), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Needs review'));
    await tester.tap(find.text('Needs review'));
    await tester.pumpAndSettle();
    expect(find.text('Consolidate · +5 XP'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('rewrite-field')),
      'The browser sends a request and builds the DOM',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Consolidate · +5 XP'));
    await tester.tap(find.text('Consolidate · +5 XP'));
    await tester.pumpAndSettle();

    expect(model.completed, 1);
    expect(model.points, 5);
    expect(repository.scores['fe-1'], 5);
    await tester.ensureVisible(find.text('Next question'));
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    expect(find.text('How do debounce and throttle differ?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing appLocale switches the UI instantly', (tester) async {
    final repository = MemoryProgressRepository();
    final model = TrainingViewModel(repository);
    await model.load();
    final appLocale = ValueNotifier<Locale?>(const Locale('en'));
    await tester.pumpWidget(
      DevmateApp(
        viewModel: model,
        llmSettings: LlmSettingsRepository(),
        catalog: TopicCatalog(baseTopics: questionCatalogFor('en')),
        appLocale: appLocale,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TECH INTERVIEW PREP'), findsOneWidget);

    appLocale.value = const Locale('ru');
    await tester.pumpAndSettle();

    final ruEyebrow = lookupAppLocalizations(const Locale('ru')).homeEyebrow;
    expect(find.text(ruEyebrow), findsOneWidget);
    expect(find.text('TECH INTERVIEW PREP'), findsNothing);
  });

  testWidgets('theme defaults to dark and switches instantly via notifier', (
    tester,
  ) async {
    final repository = MemoryProgressRepository();
    final model = TrainingViewModel(repository);
    await model.load();
    final themeMode = ValueNotifier<ThemeMode>(ThemeMode.dark);
    await tester.pumpWidget(
      DevmateApp(
        viewModel: model,
        llmSettings: LlmSettingsRepository(),
        catalog: TopicCatalog(baseTopics: questionCatalogFor('en')),
        themeMode: themeMode,
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(Theme.of(context).scaffoldBackgroundColor, DevmateColors.canvas);

    themeMode.value = ThemeMode.light;
    await tester.pumpAndSettle();

    expect(Theme.of(context).brightness, Brightness.light);
    expect(Theme.of(context).scaffoldBackgroundColor, const Color(0xFFF7F9F6));

    themeMode.value = ThemeMode.system;
    await tester.pumpAndSettle();
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
