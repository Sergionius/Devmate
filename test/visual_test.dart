import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/question_catalog.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/chat_screen.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/home_screen.dart';
import 'package:devmate/ui/practice_screen.dart';
import 'package:devmate/ui/topic_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/memory_secure_storage.dart';

class _EmptyProgress implements ProgressRepository {
  @override
  Future<Map<String, int>> load() async => {};
  @override
  Future<void> save(Map<String, int> scores) async {}
}

void main() {
  // Компактный телефон с увеличенным системным текстом: основные экраны
  // не должны вызывать переполнений (RenderFlex overflow и т.п.).
  Future<void> pumpCompactAtLargerText(
    WidgetTester tester,
    Widget child,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: devmateTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.4),
          ),
          child: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  testWidgets('practice screen fits compact layout at larger text scale', (
    tester,
  ) async {
    final model = TrainingViewModel(_EmptyProgress());
    await model.load();
    await pumpCompactAtLargerText(
      tester,
      PracticeScreen(
        topic: questionCatalog.first,
        initialIndex: 0,
        viewModel: model,
      ),
    );
    expect(find.byKey(const Key('answer-field')), findsOneWidget);
  });

  testWidgets('Done dismisses the answer keyboard without losing the draft', (
    tester,
  ) async {
    final model = TrainingViewModel(_EmptyProgress());
    await model.load();
    await pumpCompactAtLargerText(
      tester,
      PracticeScreen(
        topic: questionCatalog.first,
        initialIndex: 0,
        viewModel: model,
      ),
    );
    final field = find.byKey(const Key('answer-field'));
    await tester.enterText(field, 'My draft answer');
    final textField = tester.widget<TextField>(field);
    expect(textField.textInputAction, TextInputAction.done);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(textField.controller!.text, 'My draft answer');
    expect(find.byKey(const Key('answer-field')), findsOneWidget);
  });

  testWidgets('home screen fits compact layout at larger text scale', (
    tester,
  ) async {
    final catalog = TopicCatalog();
    final model = TrainingViewModel(
      _EmptyProgress(),
      catalogRepository: catalog,
    );
    await model.load();
    await pumpCompactAtLargerText(
      tester,
      HomeScreen(
        viewModel: model,
        catalog: catalog,
        settingsRepository: LlmSettingsRepository(
          storage: MemorySecureStorage(),
        ),
      ),
    );
    // Карточки темы видимы и не переполняются при фиксированной высоте
    // плитки, масштабируемой вместе с текстом; на крупном шрифте первая
    // плитка уходит за первый экран, поэтому прокручиваем к ней.
    await tester.scrollUntilVisible(
      find.text(catalog.topics.first.title),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(catalog.topics.first.title), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(catalog.topics.last.title),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('topic screen fits compact layout at larger text scale', (
    tester,
  ) async {
    final catalog = TopicCatalog();
    final topic = catalog.topics.first;
    final model = TrainingViewModel(
      _EmptyProgress(),
      catalogRepository: catalog,
    );
    await model.load();
    await pumpCompactAtLargerText(
      tester,
      TopicScreen(topic: topic, viewModel: model, catalog: catalog),
    );
    expect(find.text(topic.title), findsOneWidget);
  });

  testWidgets('chat screen fits compact layout at larger text scale', (
    tester,
  ) async {
    final storage = MemorySecureStorage()
      ..values['llm.baseUrl'] = 'https://example.com/v1'
      ..values['llm.model'] = 'test-model'
      ..values['llm.apiKey'] = 'test-key';
    await pumpCompactAtLargerText(
      tester,
      ChatScreen(
        title: 'AI',
        systemPrompt: 'sys',
        intro: 'Intro',
        settingsRepository: LlmSettingsRepository(storage: storage),
        suggestions: const ['First suggestion', 'Second suggestion'],
      ),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('First suggestion'), findsOneWidget);
  });
}
