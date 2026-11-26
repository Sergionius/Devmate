import 'dart:async';

import 'package:devmate/data/chat_history_repository.dart';
import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/router.dart';
import 'package:devmate/ui/chat_screen.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';

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
    );

    unawaited(model.load());
    final router = createRouter(
      model,
      LlmSettingsRepository(storage: MemorySecureStorage()),
      TopicCatalog(),
      chatHistory: ChatHistoryRepository(
        openDatabase: () => databaseFactoryMemory.openDatabase('chat-cta-test'),
      ),
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
    await tester.tap(find.text('New chat'));
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
    expect(
      router.routeInformationProvider.value.uri.path,
      startsWith('/chat/free/'),
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);
  });
  testWidgets(
    'returning from AI settings does not retain a disposed chat session',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/chat',
        routes: [
          GoRoute(
            path: '/chat',
            builder: (context, _) => ChatScreen(
              title: 'AI',
              systemPrompt: 'sys',
              intro: 'Intro',
              settingsRepository: repoWith(configuredStorage),
              sessionFactory: (_, _) => _FakeSession('Reply'),
            ),
          ),
          GoRoute(
            path: '/settings/ai',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ),
          ),
          GoRoute(
            path: '/else',
            builder: (context, _) => const Scaffold(body: Text('Else')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('AI settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      router.go('/else');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stream ending after settings return safely releases old session',
    (tester) async {
      final active = _SlowStartSession();
      var creations = 0;
      final router = GoRouter(
        initialLocation: '/chat',
        routes: [
          GoRoute(
            path: '/chat',
            builder: (context, _) => ChatScreen(
              title: 'AI',
              systemPrompt: 'sys',
              intro: 'Intro',
              settingsRepository: repoWith(configuredStorage),
              sessionFactory: (_, _) =>
                  creations++ == 0 ? active : _FakeSession('New'),
            ),
          ),
          GoRoute(
            path: '/settings/ai',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back'),
              ),
            ),
          ),
          GoRoute(
            path: '/else',
            builder: (context, _) => const Scaffold(body: Text('Else')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();
      await tester.tap(find.byTooltip('AI settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pump();
      active.release();
      await tester.pumpAndSettle();
      router.go('/else');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'question chat shows the question before messaging and prefills draft',
    (tester) async {
      final session = _FakeSession('AI reply');
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(
            title: 'Question 1',
            systemPrompt: 'sys',
            intro: 'Intro',
            settingsRepository: repoWith(configuredStorage),
            initialQuestion: 'What is a widget?',
            initialInput: 'My draft answer',
            sessionFactory: (_, _) => session,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('What is a widget?'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'My draft answer',
      );
      expect(session.history, isEmpty);
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();
      expect(session.history.first.text, 'My draft answer');
      expect(find.text('What is a widget?'), findsOneWidget);
    },
  );

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

      expect(find.byType(DevmateDotsLoader), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      session.release();
      await tester.pumpAndSettle();
      expect(find.byType(DevmateDotsLoader), findsNothing);
      expect(find.textContaining('partial'), findsOneWidget);
      expect(find.textContaining('answer'), findsOneWidget);

      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    },
  );

  testWidgets('reader position stays anchored when streamed reply grows', (
    tester,
  ) async {
    final session = _ScrollSession();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          title: 'AI',
          systemPrompt: 'sys',
          intro: 'Intro',
          settingsRepository: repoWith(configuredStorage),
          sessionFactory: (_, _) => session,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'new question');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    final list = find.byType(ListView).first;
    final controller = tester.widget<ListView>(list).controller!;
    await tester.drag(list, const Offset(0, 120));
    await tester.pump(const Duration(seconds: 1));
    final oldOffset = controller.offset;
    final oldMax = controller.position.maxScrollExtent;
    expect(oldOffset, greaterThan(48));
    session.addChunk(List.filled(120, 'extended answer').join(' '));
    await tester.pump();
    await tester.pump();
    expect(
      controller.offset,
      greaterThan(oldOffset),
      reason:
          'max before $oldMax, after ${controller.position.maxScrollExtent}',
    );
    final drag = await tester.startGesture(tester.getCenter(list));
    await drag.moveBy(const Offset(0, 55));
    await tester.pump();
    final draggingOffset = controller.offset;
    session.addChunk(List.filled(50, 'more text').join(' '));
    await tester.pump();
    await tester.pump();
    expect(controller.offset, closeTo(draggingOffset, 2));
    await drag.up();
    session.finish();
    await tester.pumpAndSettle();
  });

  testWidgets('failed response can be retried and message actions open', (
    tester,
  ) async {
    final session = _FailingSession();
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          title: 'AI',
          systemPrompt: 'sys',
          intro: 'Intro',
          settingsRepository: repoWith(configuredStorage),
          sessionFactory: (_, _) => session,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(session.history, hasLength(2));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(session.history, hasLength(2));
    expect(session.history.last.text, 'Recovered');
    expect(
      tester
          .widget<SelectionArea>(find.byType(SelectionArea).first)
          .contextMenuBuilder,
      isNotNull,
    );
    await tester.longPress(find.text('hello'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copied, 'hello');
  });
}

class _ScrollSession extends ChangeNotifier implements ChatSession {
  final _history = <LlmChatMessage>[
    for (var i = 0; i < 28; i++) ...[
      LlmChatMessage(LlmRole.user, 'Archived question $i'),
      LlmChatMessage(
        LlmRole.assistant,
        'Archived reply $i, with enough text to take up room in the list.',
      ),
    ],
  ];
  final _controller = StreamController<String>();

  @override
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  @override
  Stream<String> sendMessageStream(String prompt, {bool retry = false}) {
    _history
      ..add(LlmChatMessage(LlmRole.user, prompt))
      ..add(LlmChatMessage(LlmRole.assistant, ''));
    notifyListeners();
    return _controller.stream;
  }

  void addChunk(String text) {
    _history.last.text += text;
    notifyListeners();
    _controller.add(text);
  }

  void finish() {
    unawaited(_controller.close());
  }

  @override
  void dispose() {
    if (!_controller.isClosed) unawaited(_controller.close());
    super.dispose();
  }
}

class _FailingSession extends ChangeNotifier implements ChatSession {
  final _history = <LlmChatMessage>[];
  var attempts = 0;

  @override
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  @override
  Stream<String> sendMessageStream(String prompt, {bool retry = false}) async* {
    if (retry) {
      _history.removeLast();
    } else {
      _history.add(LlmChatMessage(LlmRole.user, prompt));
    }
    final answer = LlmChatMessage(LlmRole.assistant, '');
    _history.add(answer);
    notifyListeners();
    attempts++;
    if (attempts == 1) {
      answer.failed = true;
      answer.errorKind = LlmErrorKind.connection;
    } else {
      answer.text = 'Recovered';
    }
    notifyListeners();
    yield answer.text;
  }
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
  Stream<String> sendMessageStream(String prompt, {bool retry = false}) async* {
    _history
      ..add(LlmChatMessage(LlmRole.user, prompt))
      ..add(LlmChatMessage(LlmRole.assistant, ''));
    notifyListeners();
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
  Stream<String> sendMessageStream(String prompt, {bool retry = false}) async* {
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
