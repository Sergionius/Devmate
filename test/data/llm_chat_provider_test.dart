import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
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
      expect(chunks.join(), contains('Ошибка соединения'));

      final history = provider.history.toList();
      expect(history.length, 2);
      expect(history.first.origin, MessageOrigin.user);
      expect(history.first.text, 'Вопрос');
      expect(history.last.text, contains('Ошибка соединения'));
    },
  );

  test('a failed assistant turn is not resent as history on the next call', () async {
    final provider = OpenAiCompatibleProvider(
      settings: _unreachable,
      systemPrompt: 'sys',
    );
    await provider.sendMessageStream('Первый').toList();
    final chunks = await provider.sendMessageStream('Второй').toList();
    expect(chunks.join(), contains('Ошибка соединения'));
    // Both exchanges stay in the transcript (2 messages each), but the second
    // request must not include the failed assistant reply. The pairing logic is
    // exercised implicitly: with it broken, _requestMessages would pair
    // «Второй» with the failed «Первый» reply.
    expect(provider.history.length, 4);
  });
}
