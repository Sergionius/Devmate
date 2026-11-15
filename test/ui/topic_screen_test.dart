import 'package:devmate/data/progress_repository.dart';


import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/topic_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('сброс раздела требует подтверждения и сохраняет остальные', (
    tester,
  ) async {
    final catalog = TopicCatalog();
    final topic = catalog.topics.first;
    final other = catalog.topics[1];
    final repository = _MemoryProgress();
    final model = TrainingViewModel(repository, catalogRepository: catalog);
    await model.load();
    await model.record(topic.questions.first, knewAnswer: true);
    await model.record(other.questions.first, knewAnswer: false);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopicScreen(topic: topic, viewModel: model, catalog: catalog),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(
      OutlinedButton,
      'Сбросить прогресс раздела',
    );
    await tester.scrollUntilVisible(
      button,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('«Frontend»'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(model.completedIn(topic), 1);
    await tester.tap(button.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить прогресс раздела').last);
    await tester.pumpAndSettle();
    expect(model.completedIn(topic), 0);
    expect(model.completedIn(other), 1);
    expect(
      catalog.topicById(topic.id)!.questions.length,
      topic.questions.length,
    );
    expect(repository.scores.keys, [other.questions.first.id]);
    expect(tester.widget<OutlinedButton>(button.first).onPressed, isNull);
  });
}
