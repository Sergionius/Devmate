import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/edit_topic_screen.dart';
import 'package:devmate/ui/platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDevmateSimulateWeb = false;
  });

  Future<String> pumpScreen(
    WidgetTester tester, {
    TopicCatalog? catalog,
  }) async {
    final effectiveCatalog = catalog ?? TopicCatalog();
    final topic = await effectiveCatalog.addUserTopic('Docker', 'Containers', [
      ('What is an image?', 'A template.'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        theme: devmateTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EditTopicScreen(catalog: effectiveCatalog, topicId: topic.id),
      ),
    );
    await tester.pumpAndSettle();
    return topic.id;
  }

  /// Runs [body] with the given target platform, resetting the override
  /// inside the test body as required by the framework invariants.
  Future<void> withPlatform(
    WidgetTester tester,
    TargetPlatform? platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
      await tester.pumpAndSettle();
    }
  }

  testWidgets('creating a question validates inline and saves', (tester) async {
    final catalog = TopicCatalog();
    final topicId = await pumpScreen(tester, catalog: catalog);

    await tester.tap(find.text('Add question'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // Saving with empty fields keeps the form open and shows the
    // validation message inline.
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Fill in the question and the answer.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Question'),
      'What is a layer?',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Reference answer'),
      'A step of the build.',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Saved and confirmed with the same notice as before.
    expect(find.text('Saved'), findsOneWidget);
    final docker = catalog.topicById(topicId)!;
    expect(docker.questions.last.prompt, 'What is a layer?');
    expect(docker.questions.last.answer, 'A step of the build.');
  });

  testWidgets('cancel closes the form without changes', (tester) async {
    final catalog = TopicCatalog();
    final topicId = await pumpScreen(tester, catalog: catalog);

    await tester.tap(find.text('Add question'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Question'),
      'Discarded draft',
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    final prompts = catalog.topicById(topicId)!.questions.map((q) => q.prompt);
    expect(prompts, ['What is an image?']);
  });

  testWidgets('editing keeps the existing text and updates the question', (
    tester,
  ) async {
    final catalog = TopicCatalog();
    final topicId = await pumpScreen(tester, catalog: catalog);

    await tester.tap(find.text('What is an image?'));
    await tester.pumpAndSettle();
    expect(find.text('Edit question'), findsOneWidget);
    // The answer field is prefilled with the existing answer.
    final answerEditable = tester.widget<EditableText>(
      find
          .descendant(
            of: find.widgetWithText(TextField, 'Reference answer'),
            matching: find.byType(EditableText),
          )
          .first,
    );
    expect(answerEditable.controller.text, 'A template.');

    await tester.enterText(
      find.widgetWithText(TextField, 'Question'),
      'What is a container?',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Saved'), findsOneWidget);
    final updated = catalog.topicById(topicId)!.questions.single;
    expect(updated.prompt, 'What is a container?');
    expect(updated.answer, 'A template.');
  });

  testWidgets('failed save keeps the form open with the entered text', (
    tester,
  ) async {
    final catalog = _BrokenCatalog();
    final topicId = await pumpScreen(tester, catalog: catalog);

    await tester.tap(find.text('What is an image?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Question'),
      'Rewritten prompt',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The error is shown inside the form, the form stays open and the
    // entered text is not lost.
    expect(find.text('Failed to save the topic. Try again.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Rewritten prompt'))
          .controller!
          .text,
      'Rewritten prompt',
    );
    expect(
      catalog.topicById(topicId)!.questions.single.prompt,
      'What is an image?',
    );
  });

  testWidgets('iOS question actions stack and keyboard gap has sheet color', (
    tester,
  ) async {
    await withPlatform(tester, TargetPlatform.iOS, () async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await pumpScreen(tester);
      await tester.tap(find.text('Add question'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Save');
      final cancel = find.widgetWithText(TextButton, 'Cancel');
      expect(save, findsOneWidget);
      expect(cancel, findsOneWidget);
      expect(tester.getTopLeft(save).dx, tester.getTopLeft(cancel).dx);
      expect(
        tester.getBottomLeft(save).dy,
        lessThan(tester.getTopLeft(cancel).dy),
      );

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final backing = find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == DevmateColors.surfaceRaised,
      );
      expect(backing, findsOneWidget);
      expect(tester.getBottomLeft(backing).dy, 844);
      expect(
        tester.getTopLeft(backing).dy,
        lessThanOrEqualTo(tester.getBottomLeft(cancel).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('delete question on iOS uses the Cupertino confirmation', (
    tester,
  ) async {
    await withPlatform(tester, TargetPlatform.iOS, () async {
      final catalog = TopicCatalog();
      final topicId = await pumpScreen(tester, catalog: catalog);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      // Platform contract: Cupertino alert, no Material dialog.
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(catalog.topicById(topicId)!.questions, hasLength(1));

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(catalog.topicById(topicId)!.questions, isEmpty);
    });
  });

  testWidgets('delete question on Android uses the Material confirmation', (
    tester,
  ) async {
    await withPlatform(tester, TargetPlatform.android, () async {
      final catalog = TopicCatalog();
      final topicId = await pumpScreen(tester, catalog: catalog);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CupertinoAlertDialog), findsNothing);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(catalog.topicById(topicId)!.questions, hasLength(1));

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(catalog.topicById(topicId)!.questions, isEmpty);
    });
  });

  testWidgets('question form on web is a width-capped dialog with focus', (
    tester,
  ) async {
    debugDevmateSimulateWeb = true;
    await withPlatform(tester, TargetPlatform.macOS, () async {
      final catalog = TopicCatalog();
      final topicId = await pumpScreen(tester, catalog: catalog);

      await tester.tap(find.text('Add question'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      // Reasonable desktop width cap from the adaptive form chrome.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox &&
              widget.constraints.maxWidth == 600 &&
              widget.constraints.maxHeight.isFinite,
        ),
        findsOneWidget,
      );
      // Creating a question puts keyboard focus on the prompt field.
      final promptEditable = tester.widget<EditableText>(
        find
            .descendant(
              of: find.widgetWithText(TextField, 'Question'),
              matching: find.byType(EditableText),
            )
            .first,
      );
      expect(promptEditable.focusNode.hasFocus, isTrue);

      await tester.enterText(
        find.widgetWithText(TextField, 'Question'),
        'Web question?',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reference answer'),
        'Web answer.',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(
        catalog.topicById(topicId)!.questions.last.prompt,
        'Web question?',
      );
      expect(catalog.topicById(topicId)!.questions.last.answer, 'Web answer.');
    });
  });
}

/// Catalog whose question updates always fail, to exercise the inline
/// error path of the edit form.
class _BrokenCatalog extends TopicCatalog {
  @override
  Future<void> updateQuestion(
    String questionId,
    String prompt,
    String answer,
  ) async {
    throw Exception('save failed');
  }
}
