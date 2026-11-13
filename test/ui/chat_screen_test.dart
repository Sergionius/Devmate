import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/ui/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('ChatScreen offers settings when no key is configured', (
    tester,
  ) async {
    final repo = LlmSettingsRepository(storage: MemorySecureStorage());
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          title: 'AI',
          systemPrompt: 'sys',
          settingsRepository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Нужен API-ключ'), findsOneWidget);
    expect(find.text('Открыть настройки'), findsOneWidget);
  });
}
