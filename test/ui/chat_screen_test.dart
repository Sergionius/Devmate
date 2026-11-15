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

      // Аппаратный Enter (симулятор iOS, десктоп, web).
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Сообщение ушло: пузырь пользователя появился, поле пустое.
      expect(find.text('привет'), findsOneWidget);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, isEmpty);
      // Клавиатура закрыта: фокус больше не в поле ввода.
      expect(editable.focusNode.hasFocus, isFalse);
    },
  );

  testWidgets('empty input: Enter only closes the keyboard', (tester) async {
    final repo = repoWith(configuredStorage);
    await tester.pumpWidget(
      MaterialApp(
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

    // Пустой ввод не отправляется: пузыря нет, в поле — те же пробелы.
    expect(find.text('   '), findsOneWidget);
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text, '   ');
    // Но клавиатура закрывается.
    expect(editable.focusNode.hasFocus, isFalse);
  });
}
