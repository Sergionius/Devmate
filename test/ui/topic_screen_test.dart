import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/topic_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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
  testWidgets('empty topic updates when a question is added manually', (
    tester,
  ) async {
    final catalog = TopicCatalog(baseTopics: []);
    final topic = await catalog.addUserTopic('My topic', 'Description', []);
    final model = TrainingViewModel(_MemoryProgress());
    await model.load();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopicScreen(topic: topic, viewModel: model, catalog: catalog),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Repeat topic'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await catalog.addQuestionsToTopic(topic.id, [('First question', 'Answer')]);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('First question'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('First question'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('section reset requires confirmation and keeps other topics', (
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
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TopicScreen(topic: topic, viewModel: model, catalog: catalog),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Reset topic progress');
    await tester.scrollUntilVisible(
      button,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button.first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Frontend'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(model.completedIn(topic), 1);
    await tester.tap(button.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset topic progress').last);
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
