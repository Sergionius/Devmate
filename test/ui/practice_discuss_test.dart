import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/domain/question.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/practice_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Кнопка «Разобрать с AI» должна быть доступна на сравнении с эталоном
/// и на стадии «нужно повторить» (до сохранения результата).
void main() {
  const topic = InterviewTopic(
    't1',
    'Тема',
    'Описание',
    [InterviewQuestion('q1', 'Вопрос?', 'Эталон.')],
  );

  Future<GoRouter> pumpPractice(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/topic/t1/practice/0',
      routes: [
        GoRoute(
          path: '/topic/:topicId/practice/:index',
          builder: (context, state) => PracticeScreen(
            topic: topic,
            initialIndex: 0,
            viewModel: TrainingViewModel(_MemoryProgressRepository())..load(),
          ),
        ),
        GoRoute(
          path: '/chat/question/:topicId/:index',
          builder: (context, state) =>
              const Center(child: Text('маркер-чата-вопроса')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  /// Тап по цели: на маленьком окне теста кнопки ниже сгиба.
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('на сравнении есть кнопка разбора с AI, она открывает чат', (
    tester,
  ) async {
    await pumpPractice(tester);

    await tester.enterText(find.byKey(const Key('answer-field')), 'Мой ответ');
    await tapVisible(tester, find.text('Сверить с эталоном'));
    // Сравнение реально показано.
    expect(find.text('Нужно повторить'), findsOneWidget);

    await tapVisible(tester, find.text('Разобрать с AI'));
    expect(find.text('маркер-чата-вопроса'), findsOneWidget);
  });

  testWidgets('на «нужно повторить» тоже есть кнопка разбора с AI', (
    tester,
  ) async {
    await pumpPractice(tester);

    await tester.enterText(find.byKey(const Key('answer-field')), 'Мой ответ');
    await tapVisible(tester, find.text('Сверить с эталоном'));
    expect(find.text('Нужно повторить'), findsOneWidget);
    await tapVisible(tester, find.text('Нужно повторить'));
    // Стадия закрепления: поле и кнопка разбора с AI.
    expect(find.byKey(const Key('rewrite-field')), findsOneWidget);

    await tapVisible(tester, find.text('Разобрать с AI'));
    expect(find.text('маркер-чата-вопроса'), findsOneWidget);
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
