import 'package:devmate/data/question_catalog.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/practice_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyProgress implements ProgressRepository {
  @override
  Future<Map<String, int>> load() async => {};
  @override
  Future<void> save(Map<String, int> scores) async {}
}

void main() {
  testWidgets('practice screen fits compact layout at larger text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final model = TrainingViewModel(_EmptyProgress());
    await model.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: devmateTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.4),
          ),
          child: PracticeScreen(
            topic: questionCatalog.first,
            initialIndex: 0,
            viewModel: model,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('answer-field')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
