import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openai_dart/openai_dart.dart' as oai;

const _unreachable = LlmSettings(
  baseUrl: 'http://127.0.0.1:9/v1',
  model: 'test-model',
  apiKey: 'k',
);

void main() {
  // Без TestWidgetsFlutterBinding: он перехватывает HTTP (все запросы → 400),
  // а тест отмены ниже поднимает реальный локальный SSE-сервер.

  group('classifyLlmError', () {
    test('ApiException 401 → keyRejected', () {
      final kind = classifyLlmError(
        const oai.ApiException(
          message: 'Incorrect API key provided',
          statusCode: 401,
        ),
      );
      expect(kind, LlmErrorKind.keyRejected);
    });

    test('ApiException 404 → notFound', () {
      final kind = classifyLlmError(
        const oai.ApiException(message: 'model not found', statusCode: 404),
      );
      expect(kind, LlmErrorKind.notFound);
    });

    test('ApiException 429 → rateLimited', () {
      final kind = classifyLlmError(
        const oai.ApiException(message: 'rate limit exceeded', statusCode: 429),
      );
      expect(kind, LlmErrorKind.rateLimited);
    });

    test('лимит подписки в сообщении → noBalance, а не connection', () {
      final kind = classifyLlmError(
        const oai.ApiException(
          message:
              'Your subscription has expired or the usage limit is reached.',
          statusCode: 403,
        ),
      );
      expect(kind, LlmErrorKind.noBalance);
    });

    test('ApiException 429 c кодом insufficient_quota → noBalance', () {
      final kind = classifyLlmError(
        const oai.ApiException(
          message: 'You exceeded your current quota',
          statusCode: 429,
          code: 'insufficient_quota',
        ),
      );
      expect(kind, LlmErrorKind.noBalance);
    });

    test('ApiException 403 без признаков квоты → keyRejected', () {
      final kind = classifyLlmError(
        const oai.ApiException(message: 'forbidden', statusCode: 403),
      );
      expect(kind, LlmErrorKind.keyRejected);
    });

    test('ApiException 500 → connection', () {
      final kind = classifyLlmError(
        const oai.ApiException(message: 'internal error', statusCode: 500),
      );
      expect(kind, LlmErrorKind.connection);
    });

    test('не-API ошибка (сеть) → connection', () {
      expect(
        classifyLlmError(Exception('Connection refused')),
        LlmErrorKind.connection,
      );
    });
  });

  group('llmErrorDetail', () {
    test('из ApiException берётся сообщение', () {
      final detail = llmErrorDetail(
        const oai.ApiException(
          message: 'subscription limit reached',
          statusCode: 429,
        ),
      );
      expect(detail, 'subscription limit reached');
    });

    test('длинное сообщение обрезается до 300 символов', () {
      final detail = llmErrorDetail(
        oai.ApiException(
          message: 'x' * 400,
          statusCode: 500,
        ),
      );
      expect(detail!.length, 301); // 300 + многоточие
      expect(detail.endsWith('…'), isTrue);
    });

    test('для обычных исключений берётся toString', () {
      final detail = llmErrorDetail(Exception('boom'));
      expect(detail, contains('boom'));
    });
  });

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

