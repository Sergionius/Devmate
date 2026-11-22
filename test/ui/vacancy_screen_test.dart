import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/domain/question.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/platform_ui.dart';
import 'package:devmate/ui/vacancy_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/memory_secure_storage.dart';

void main() {
  testWidgets('disabling AI hides vacancy import even on an open screen', (
    tester,
  ) async {
    final disabled = ValueNotifier<bool>(false);
    addTearDown(disabled.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VacancyScreen(
          catalog: TopicCatalog(),
          settings: LlmSettingsRepository(storage: MemorySecureStorage()),
          aiDisabled: disabled,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Generate questions'), findsOneWidget);
    final input = tester.widget<TextField>(find.byType(TextField).first);
    expect(input.minLines, 1);
    expect(input.maxLines, 12);
    expect(input.decoration?.hintText, isNotEmpty);
    disabled.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Generate questions'), findsNothing);
    expect(
      find.textContaining('Job posting import is unavailable'),
      findsOneWidget,
    );
  });

  testWidgets('iOS destination uses an action sheet and adaptive fields', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    await settings.save(
      const LlmSettings(
        baseUrl: 'https://example.com/v1',
        model: 'test',
        apiKey: 'test',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VacancyScreen(
          catalog: TopicCatalog(
            baseTopics: const [
              InterviewTopic('existing', 'Flutter', 'UI', [
                InterviewQuestion(
                  'q',
                  'What is a widget?',
                  'An immutable description.',
                ),
              ]),
            ],
          ),
          settings: settings,
          sessionFactory: (_, _) => _PreviewSession(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Flutter role');
    await tester.tap(find.text('Generate questions'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    await tester.ensureVisible(find.text('Save to'));
    final fieldRight = tester.getTopRight(find.byType(DevmateSelectionField));
    final arrowRight = tester.getTopRight(
      find.byIcon(CupertinoIcons.chevron_down),
    );
    expect(fieldRight.dx - arrowRight.dx, lessThan(40));
    await tester.tap(find.text('Save to'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    await tester.tap(find.text('Flutter').last);
    await tester.pumpAndSettle();
    expect(find.text('Flutter'), findsOneWidget);
    expect(find.text('Topic description'), findsNothing);
  });

  testWidgets('generated questions have a visible gap between cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    await settings.save(
      const LlmSettings(
        baseUrl: 'https://example.com/v1',
        model: 'test',
        apiKey: 'test',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VacancyScreen(
          catalog: TopicCatalog(),
          settings: settings,
          sessionFactory: (_, _) => _PreviewSession(
            response:
                '{"title":"Practice","questions":['
                '{"prompt":"First?","answer":"One."},'
                '{"prompt":"Second?","answer":"Two."}]}',
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Flutter role');
    await tester.tap(find.text('Generate questions'));
    await tester.pumpAndSettle();
    final cards = find.byType(Card);
    expect(cards, findsNWidgets(2));
    final firstSurface = find
        .descendant(of: cards.at(0), matching: find.byType(Material))
        .first;
    final secondSurface = find
        .descendant(of: cards.at(1), matching: find.byType(Material))
        .first;
    final gap =
        tester.getTopLeft(secondSurface).dy -
        tester.getBottomLeft(firstSurface).dy;
    expect(gap, greaterThanOrEqualTo(16));
  });

  testWidgets(
    'iOS question editor validates and closes without disposed controllers',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final settings = LlmSettingsRepository(storage: MemorySecureStorage());
      await settings.save(
        const LlmSettings(
          baseUrl: 'https://example.com/v1',
          model: 'test',
          apiKey: 'test',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VacancyScreen(
            catalog: TopicCatalog(),
            settings: settings,
            sessionFactory: (_, _) => _PreviewSession(),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Flutter role');
      await tester.tap(find.text('Generate questions'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Question?'));
      await tester.tap(find.text('Question?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('at least one complete question'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('generation uses the app spinner with a centered status', (
    tester,
  ) async {
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    await settings.save(
      const LlmSettings(
        baseUrl: 'https://example.com/v1',
        model: 'test',
        apiKey: 'test',
      ),
    );
    final session = _WaitingSession();
    await tester.pumpWidget(
      MaterialApp(
        theme: devmateTheme(),
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VacancyScreen(
          catalog: TopicCatalog(),
          settings: settings,
          sessionFactory: (_, _) => session,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Flutter role');
    await tester.tap(find.text('Generate questions'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(DevmateDotsLoader), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final field = find.byType(TextField).first;
    expect(tester.widget<TextField>(field).enabled, isFalse);
    expect(
      Theme.of(tester.element(field)).inputDecorationTheme.disabledBorder,
      isA<OutlineInputBorder>(),
    );
    expect(
      tester.widget<Text>(find.text('Generating questions…')).textAlign,
      TextAlign.center,
    );
    session.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('regeneration asks before discarding edited preview', (
    tester,
  ) async {
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    await settings.save(
      const LlmSettings(
        baseUrl: 'https://example.com/v1',
        model: 'test',
        apiKey: 'test',
      ),
    );
    var generations = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: VacancyScreen(
          catalog: TopicCatalog(),
          settings: settings,
          sessionFactory: (_, _) {
            generations++;
            return _PreviewSession();
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Flutter role');
    await tester.tap(find.text('Generate questions'));
    await tester.pumpAndSettle();
    expect(generations, 1);
    await tester.drag(find.byType(ListView), const Offset(0, -550));
    await tester.pumpAndSettle();
    expect(find.text('Question?'), findsOneWidget);
    await tester.ensureVisible(find.text('Generate questions'));
    await tester.tap(find.text('Generate questions'));
    await tester.pumpAndSettle();
    expect(find.text('Replace the current preview?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Question?'), findsOneWidget);
    expect(generations, 1);
  });
}

class _WaitingSession extends ChangeNotifier implements ChatSession {
  final _gate = Completer<void>();
  final _history = <LlmChatMessage>[];
  @override
  List<LlmChatMessage> get history => _history;

  void complete() => _gate.complete();

  @override
  Stream<String> sendMessageStream(String prompt, {bool retry = false}) async* {
    _history.add(LlmChatMessage(LlmRole.user, prompt));
    await _gate.future;
    _history.add(
      LlmChatMessage(
        LlmRole.assistant,
        '{"questions":[{"prompt":"Question?","answer":"Answer."}]}',
      ),
    );
    yield _history.last.text;
  }
}

class _PreviewSession extends ChangeNotifier implements ChatSession {
  _PreviewSession({
    this.response = '{"title":"Practice","questions":[{"prompt":"Question?","answer":"Reference."}]}',
  });

  final String response;
  final _history = <LlmChatMessage>[];
  @override
  List<LlmChatMessage> get history => _history;

  @override
  Stream<String> sendMessageStream(String prompt, {bool retry = false}) async* {
    _history.add(LlmChatMessage(LlmRole.user, prompt));
    _history.add(LlmChatMessage(LlmRole.assistant, response));
    yield response;
  }
}
