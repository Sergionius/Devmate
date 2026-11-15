import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';

import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/chat_screen.dart';
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

  testWidgets('ChatScreen offers settings when no key is configured', (
    tester,
  ) async {
    final repo = repoWith(MemorySecureStorage());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          title: 'AI',
          systemPrompt: 'sys',
          intro: 'Интро',
          settingsRepository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Нужен API-ключ'), findsOneWidget);
    expect(find.text('Открыть настройки'), findsOneWidget);
  });

  testWidgets(
    'hardware Enter sends the message and closes the keyboard, no newline',
    (tester) async {
      final repo = repoWith(configuredStorage);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChatScreen(
            title: 'AI',
            systemPrompt: 'sys',
            intro: 'Интро',
            settingsRepository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = find.byType(TextField);
      expect(input, findsOneWidget);
      await tester.enterText(input, 'привет');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(find.text('привет'), findsOneWidget);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, isEmpty);

      expect(editable.focusNode.hasFocus, isFalse);
    },
  );

  testWidgets('empty input: Enter only closes the keyboard', (tester) async {
    final repo = repoWith(configuredStorage);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          title: 'AI',
          systemPrompt: 'sys',
          intro: 'Интро',
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

  testWidgets('ответ модели с JSON вопросов виден как читаемый список', (
    tester,
  ) async {
    const reply =
        '{"questions":[{"prompt":"Что такое коммит?",'
        '"answer":"Снимок состояния."}]}';
    final session = _FakeSession(reply);
    final repo = repoWith(configuredStorage);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatScreen(
          title: 'AI',
          systemPrompt: 'sys',
          intro: 'Интро',
          settingsRepository: repo,
          sessionFactory: (_, _) => session,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'добавь вопросы');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.textContaining('Что такое коммит?'), findsWidgets);
    expect(find.textContaining('Снимок состояния.'), findsWidgets);
    expect(find.textContaining('"questions"'), findsNothing);
    expect(find.textContaining('"prompt"'), findsNothing);
  });
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
