import 'package:devmate/data/llm_settings.dart';

import 'package:devmate/data/question_catalog.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/main.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
