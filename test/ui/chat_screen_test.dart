import 'dart:async';

import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';

import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/router.dart';
import 'package:devmate/ui/chat_screen.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final configuredStorage = MemorySecureStorage()
    ..values['llm.baseUrl'] = 'https://example.com/v1'
    ..values['llm.model'] = 'test-model'
    ..values['llm.apiKey'] = 'test-key';

  LlmSettingsRepository repoWith(FlutterSecureStorage storage) =>
      LlmSettingsRepository(storage: storage);

  testWidgets('chat CTA opens the AI settings section and reloads on return', (
    tester,
  ) async {
    final model = TrainingViewModel(
      _MemoryProgressRepository(),
      catalogRepository: TopicCatalog(),
    )..load();
    final router = createRouter(
      model,
      LlmSettingsRepository(storage: MemorySecureStorage()),
      TopicCatalog(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: devmateTheme(),
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    unawaited(router.push('/chat/free'));
    await tester.pumpAndSettle();

    // Without a key the chat offers settings; the CTA leads straight to the
    // AI provider section, not to the overview.
    expect(find.text('Open settings'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings/ai');

    // Configure the provider and save.
    await tester.enterText(
      find.byType(TextField).at(0),
      'https://example.com/v1',
    );
    await tester.enterText(find.byType(TextField).at(1), 'test-model');
    await tester.ensureVisible(find.byType(TextField).at(2));
    await tester.enterText(find.byType(TextField).at(2), 'test-key');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Back to the chat: the session settings are reloaded, so the chat is
    // ready with the input field instead of the no-key CTA.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/chat/free');
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);
  });
  testWidgets('ChatScreen offers settings when no key is configured', (
    tester,
  ) async {
    final repo = repoWith(MemorySecureStorage());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          title: 'AI',
          systemPrompt: 'sys',
          intro: 'Intro',
          settingsRepository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('API key required'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets(
    'hardware Enter sends the message and closes the keyboard, no newline',
    (tester) async {
      final repo = repoWith(configuredStorage);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(
            title: 'AI',
            systemPrompt: 'sys',
            intro: 'Intro',
            settingsRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      expect(input, findsOneWidget);
      await tester.enterText(input, 'hello');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, isEmpty);

      expect(editable.focusNode.hasFocus, isFalse);
    },
  );

  testWidgets('empty input: Enter only closes the keyboard', (tester) async {
    final repo = repoWith(configuredStorage);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          title: 'AI',
          systemPrompt: 'sys',
          intro: 'Intro',
          settingsRepository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final input = find.byType(TextField);
    await tester.enterText(input, '   ');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(find.text('   '), findsOneWidget);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '   ');

    expect(editable.focusNode.hasFocus, isFalse);
  });

  testWidgets('model JSON reply renders as a readable list', (tester) async {
    const reply =
        '{"questions":[{"prompt":"What is a commit?",'
        '"answer":"A snapshot of the widget tree."}]}';
    final session = _FakeSession(reply);
    final repo = repoWith(configuredStorage);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          title: 'AI',
          systemPrompt: 'sys',
          intro: 'Intro',
          settingsRepository: repo,
          sessionFactory: (_, _) => session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'add questions');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.textContaining('What is a commit?'), findsWidgets);
    expect(find.textContaining('A snapshot of the widget tree.'), findsWidgets);
    expect(find.textContaining('"questions"'), findsNothing);
    expect(find.textContaining('"prompt"'), findsNothing);
  });

  testWidgets(
    'waiting for the first fragment shows UI-kit dots and disables input',
    (tester) async {
      final session = _SlowStartSession();
      final repo = repoWith(configuredStorage);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(
            title: 'AI',
            systemPrompt: 'sys',
            intro: 'Intro',
            settingsRepository: repo,
            sessionFactory: (_, _) => session,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'hi');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Пока первого фрагмента нет: индикатор UI kit, поле ввода отключено.
      expect(find.byType(DevmateDotsLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      // Первый фрагмент пришёл: точки исчезли, текст стримится.
      session.release();
      await tester.pumpAndSettle();
      expect(find.byType(DevmateDotsLoader), findsNothing);
      expect(find.textContaining('partial'), findsOneWidget);
      expect(find.textContaining('answer'), findsOneWidget);

      // Стриминг завершён: поле снова активно.
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    },
  );
}

class _SlowStartSession extends ChangeNotifier implements ChatSession {
  final List<LlmChatMessage> _history = [];
  Completer<void>? _gate;

  @override
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  void release() {
    _gate?.complete();
  }

  @override
  Stream<String> sendMessageStream(String prompt) async* {
    _history
      ..add(LlmChatMessage(LlmRole.user, prompt))
      ..add(LlmChatMessage(LlmRole.assistant, ''));
    notifyListeners();
    // Пауза до первого фрагмента: экран показывает индикатор ожидания.
    _gate = Completer<void>();
    await _gate!.future;
    _history.last.text += 'partial ';
    notifyListeners();
    yield 'partial ';
    _history.last.text += 'answer';
    notifyListeners();
    yield 'answer';
  }
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

class _FakeSession extends ChangeNotifier implements ChatSession {
  _FakeSession(this._reply);

  final String _reply;
  final List<LlmChatMessage> _history = [];

  @override
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  @override
  Stream<String> sendMessageStream(String prompt) async* {
    _history
      ..add(LlmChatMessage(LlmRole.user, prompt))
      ..add(LlmChatMessage(LlmRole.assistant, ''));
    notifyListeners();
    for (final chunk in _reply.split('|')) {
      _history.last.text += chunk;
      notifyListeners();
      yield chunk;
    }
  }
}
