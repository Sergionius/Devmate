import 'dart:async';

import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/question_catalog.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/main.dart';
import 'package:devmate/ui/practice_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// End-to-end smoke: launch the app, open a built-in topic, answer the first
/// question and confirm the score is persisted. Runs on a real Android
/// emulator in CI; local runs need a connected device or emulator.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch, practice a question, progress is saved', (tester) async {
    final preferences = SharedPreferencesAsync();
    await preferences.clear();
    final catalog = TopicCatalog(
      userTopicsRepository: LocalUserTopicsRepository(preferences),
      baseTopics: questionCatalogFor('en'),
    );
    await catalog.load();
    final model = TrainingViewModel(
      LocalProgressRepository(preferences),
      catalogRepository: catalog,
    );

    unawaited(model.load());

    await tester.pumpWidget(
      DevmateApp(
        viewModel: model,
        llmSettings: LlmSettingsRepository(),
        catalog: catalog,
        // Pin English: the assertions below match the en strings and must
        // not depend on the host device's system locale.
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    // Home shows the intro first; the library section builds lazily,
    // so scroll down until its heading appears.
    await _waitFor(
      tester,
      () => find.text('TECH INTERVIEW PREP').evaluate().isNotEmpty,
    );
    await tester.scrollUntilVisible(
      find.text('Pick a topic'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pick a topic'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Frontend').first,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frontend').first);
    await tester.pumpAndSettle();

    // Topic screen → the first unanswered question.
    await tester.scrollUntilVisible(
      find.text('Continue training'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue training'));
    await tester.pumpAndSettle();
    expect(find.byType(PracticeScreen), findsOneWidget);

    // Answer, compare with the reference, self-assess as "knew it".
    await tester.enterText(
      find.byKey(const Key('answer-field')),
      'DNS resolves the host, the browser opens a TCP connection and sends '
      'an HTTP request, the server responds with HTML, the browser renders '
      'the page and runs JavaScript.',
    );
    // Dismiss the simulator keyboard so drag targets and hit testing are
    // not affected by the shrunken viewport.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Compare with reference'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compare with reference'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Knew it · +10 XP'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Knew it · +10 XP'));

    // The score is persisted (10 XP for a confident answer).
    await _waitFor(tester, () => model.points == 10);
    expect(model.points, 10);
    expect(model.completed, 1);
  });
}

/// Integration tests run on a real event loop, so plain pumpAndSettle does
/// not wait for plugin work (SharedPreferences) — poll until [condition].
Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 50 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
  }
}
