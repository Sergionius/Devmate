import 'package:devmate/data/progress_repository.dart';
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
    await tester.pumpWidget(DevmateApp(viewModel: model));

    expect(find.text('Выбери тему'), findsOneWidget);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frontend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить тренировку'));
    await tester.pumpAndSettle();

    expect(find.text('Сверить с эталоном'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('answer-field')), 'Мой ответ');
    await tester.pump();
    tester.testTextInput.hide();
    await tester.ensureVisible(find.text('Сверить с эталоном'));
    await tester.tap(find.text('Сверить с эталоном'));
    await tester.pumpAndSettle();
    expect(find.text('ЭТАЛОННЫЙ ОТВЕТ', skipOffstage: false), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Нужно повторить'));
    await tester.tap(find.text('Нужно повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Закрепить · +5 XP'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('rewrite-field')),
      'Браузер отправляет запрос и строит DOM',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Закрепить · +5 XP'));
    await tester.tap(find.text('Закрепить · +5 XP'));
    await tester.pumpAndSettle();

    expect(model.completed, 1);
    expect(model.points, 5);
    expect(repository.scores['fe-1'], 5);
    await tester.ensureVisible(find.text('Следующий вопрос'));
    await tester.tap(find.text('Следующий вопрос'));
    await tester.pumpAndSettle();
    expect(find.text('Чем отличаются debounce и throttle?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
