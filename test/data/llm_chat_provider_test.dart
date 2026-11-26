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

    test(
      'a subscription limit in the message maps to noBalance, not connection',
      () {
        final kind = classifyLlmError(
          const oai.ApiException(
            message:
                'Your subscription has expired or the usage limit is reached.',
            statusCode: 403,
          ),
        );
        expect(kind, LlmErrorKind.noBalance);
      },
    );

    test('ApiException 429 with insufficient_quota maps to noBalance', () {
      final kind = classifyLlmError(
        const oai.ApiException(
          message: 'You exceeded your current quota',
          statusCode: 429,
          code: 'insufficient_quota',
        ),
      );
      expect(kind, LlmErrorKind.noBalance);
    });

    test('ApiException 403 without quota signs maps to keyRejected', () {
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

    test('a non-API error (network) maps to connection', () {
      expect(
        classifyLlmError(Exception('Connection refused')),
        LlmErrorKind.connection,
      );
    });
  });

  group('llmErrorDetail', () {
    test('the message is taken from ApiException', () {
      final detail = llmErrorDetail(
        const oai.ApiException(
          message: 'subscription limit reached',
          statusCode: 429,
        ),
      );
      expect(detail, 'subscription limit reached');
    });

    test('a long message is truncated to 300 characters', () {
      final detail = llmErrorDetail(
        oai.ApiException(message: 'x' * 400, statusCode: 500),
      );
      expect(detail!.length, 301);
      expect(detail.endsWith('…'), isTrue);
    });

    test('toString is used for plain exceptions', () {
      final detail = llmErrorDetail(Exception('boom'));
      expect(detail, contains('boom'));
    });
  });

  test(
    'sendMessageStream preserves a failed reply and both messages',
    () async {
      final provider = OpenAiCompatibleProvider(
        settings: _unreachable,
        systemPrompt: 'sys',
      );
      final chunks = await provider.sendMessageStream('Question').toList();

      expect(chunks, isEmpty);

      final history = provider.history;
      expect(history.length, 2);
      expect(history.first.role, LlmRole.user);
      expect(history.first.text, 'Question');
      expect(history.last.role, LlmRole.assistant);
      expect(history.last.failed, isTrue);
      // CI network/proxy configuration can return an HTTP error rather than
      // a socket error for localhost; classification is tested separately.
      expect(history.last.errorKind, isNotNull);
    },
  );

  test('retry replaces failed reply without duplicating user prompt', () async {
    final provider = OpenAiCompatibleProvider(
      settings: _unreachable,
      systemPrompt: 'sys',
    );
    await provider.sendMessageStream('First').toList();
    expect(provider.history.last.failed, isTrue);
    await provider.sendMessageStream('First', retry: true).toList();
    expect(provider.history.length, 2);
    expect(provider.history.first.text, 'First');
    expect(provider.history.last.failed, isTrue);
    expect(
      () => provider.sendMessageStream('Other', retry: true),
      throwsStateError,
    );
  });

  test('a failed assistant turn is excluded from later context', () async {
    final provider = OpenAiCompatibleProvider(
      settings: _unreachable,
      systemPrompt: 'sys',
    );
    await provider.sendMessageStream('First').toList();
    await provider.sendMessageStream('Second').toList();

    final history = provider.history;
    expect(history.length, 4);
    expect(history[1].failed, isTrue);
    expect(history[3].failed, isTrue);
    expect(history[1].errorKind, isNotNull);
    expect(history[3].errorKind, isNotNull);
  });
}
