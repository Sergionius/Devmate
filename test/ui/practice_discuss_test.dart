import 'package:devmate/data/progress_repository.dart';

import 'package:devmate/domain/question.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/practice_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  const topic = InterviewTopic('t1', 'Topic', 'Description', [
    InterviewQuestion('q1', 'Question?', 'Reference.'),
  ]);

  Future<GoRouter> pumpPractice(
    WidgetTester tester, {
    ValueNotifier<bool>? aiDisabled,
  }) async {
    final router = GoRouter(
      initialLocation: '/topic/t1/practice/0',
      routes: [
        GoRoute(
          path: '/topic/:topicId/practice/:index',
          builder: (context, state) => PracticeScreen(
            topic: topic,
            initialIndex: 0,
            viewModel: TrainingViewModel(_MemoryProgressRepository())..load(),
            aiDisabled: aiDisabled,
          ),
        ),
        GoRoute(
          path: '/chat/question/:topicId/:index',
          builder: (context, state) =>
              const Center(child: Text('question-chat-marker')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the comparison step offers an AI walkthrough button that opens chat',
    (tester) async {
      await pumpPractice(tester);

      await tester.enterText(
        find.byKey(const Key('answer-field')),
        'My answer',
      );
      await tapVisible(tester, find.text('Compare with reference'));

      expect(find.text('Needs review'), findsOneWidget);

      await tapVisible(tester, find.text('Work through it with AI'));
      expect(find.text('question-chat-marker'), findsOneWidget);
    },
  );

  testWidgets('the needs-review step also offers an AI walkthrough button', (
    tester,
  ) async {
    await pumpPractice(tester);

    await tester.enterText(find.byKey(const Key('answer-field')), 'My answer');
    await tapVisible(tester, find.text('Compare with reference'));
    expect(find.text('Needs review'), findsOneWidget);
    await tapVisible(tester, find.text('Needs review'));

    expect(find.byKey(const Key('rewrite-field')), findsOneWidget);

    await tapVisible(tester, find.text('Work through it with AI'));
    expect(find.text('question-chat-marker'), findsOneWidget);
  });

  testWidgets('the AI walkthrough button is hidden when AI is disabled', (
    tester,
  ) async {
    await pumpPractice(tester, aiDisabled: ValueNotifier<bool>(true));

    // Этап ответа: кнопки нет, и переход в чат недоступен даже после
    // сравнения с эталоном.
    expect(find.text('Work through it with AI'), findsNothing);

    await tester.enterText(find.byKey(const Key('answer-field')), 'My answer');
    await tapVisible(tester, find.text('Compare with reference'));
    await tapVisible(tester, find.text('Needs review'));

    expect(find.text('Work through it with AI'), findsNothing);
    expect(find.text('question-chat-marker'), findsNothing);
  });
}

class _MemoryProgressRepository implements ProgressRepository {
  Map<String, int> scores = {};

  @override
  Future<Map<String, int>> load() async => {...scores};

  @override
  Future<void> save(Map<String, int> scores) async {
    this.scores = {...scores};
  }
}
