import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:flutter_test/flutter_test.dart';

const _unreachable = LlmSettings(
  baseUrl: 'http://127.0.0.1:9/v1',
  model: 'test-model',
  apiKey: 'k',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'sendMessageStream reports a connection error and keeps both messages',
    () async {
      final provider = OpenAiCompatibleProvider(
        settings: _unreachable,
        systemPrompt: 'sys',
      );
      final chunks = await provider.sendMessageStream('Вопрос').toList();
      // Ошибка не приходит чанком: UI локализует её по errorKind.
      expect(chunks, isEmpty);

      final history = provider.history;
      expect(history.length, 2);
      expect(history.first.role, LlmRole.user);
      expect(history.first.text, 'Вопрос');
      expect(history.last.role, LlmRole.assistant);
      expect(history.last.failed, isTrue);
      expect(history.last.errorKind, LlmErrorKind.connection);
    },
  );

  test('a failed assistant turn is excluded from later context', () async {
    final provider = OpenAiCompatibleProvider(
      settings: _unreachable,
      systemPrompt: 'sys',
    );
    await provider.sendMessageStream('Первый').toList();
    await provider.sendMessageStream('Второй').toList();

    final history = provider.history;
    expect(history.length, 4);
    expect(history[1].failed, isTrue);
    expect(history[3].failed, isTrue);
    expect(history[1].errorKind, isNotNull);
    expect(history[3].errorKind, isNotNull);
    // Только успешные пары попадают в контекст запроса: обе попытки здесь
    // провалились, значит запрос собирался только из system + prompt.
  });
}
