import 'dart:convert';
import 'dart:io';

import 'package:devmate/data/codex_auth.dart';
import 'package:devmate/data/codex_chat_provider.dart';
import 'package:devmate/data/codex_token_store.dart';
import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/codex_fixtures.dart';
import '../support/memory_secure_storage.dart';

CodexTokens fixedTokens({DateTime? expiresAt}) => CodexTokens(
  access: 'fake.access.token',
  refresh: 'rt',
  expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 1)),
  accountId: 'acc-1',
);

String encodeTokens(CodexTokens tokens) => jsonEncode(tokens.toJson());

class _CapturedRequest {
  Map<String, dynamic>? body;
  final Map<String, String> headers = {};
}

Future<(HttpServer, _CapturedRequest)> startFakeCodexServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final captured = _CapturedRequest();
  server.listen((request) async {
    final body = await utf8.decoder.bind(request).join();
    captured
      ..body = jsonDecode(body) as Map<String, dynamic>
      ..headers.clear();
    request.headers.forEach((name, values) {
      captured.headers[name.toLowerCase()] = values.first;
    });
    request.response.headers.contentType = ContentType(
      'text',
      'event-stream',
      charset: 'utf-8',
    );

    final delta = jsonEncode(<String, dynamic>{
      'type': 'response.output_text.delta',
      'delta': 'ок',

      'output_index': 0,
      'content_index': 0,
    });
    request.response.write('data: $delta\n\n');
    await request.response.close();
  });
  addTearDown(server.close);
  return (server, captured);
}

void main() {
  group('buildCodexRequest', () {
    test('maps history, excludes failed and empty, sets preview fields', () {
      final history = [
        LlmChatMessage(LlmRole.user, 'вопрос 1'),
        LlmChatMessage(LlmRole.assistant, 'ответ 1'),
        LlmChatMessage(LlmRole.user, 'неудачный', failed: true),
        LlmChatMessage(LlmRole.assistant, ''),
      ];
      final request = buildCodexRequest(
        model: 'gpt-6-luna',
        systemPrompt: 'Тренер интервью',
        history: history,
        prompt: 'вопрос 2',
      );
      final json = request.toJson();
      expect(json['model'], 'gpt-6-luna');
      expect(json['store'], isFalse);
      expect(json['stream'], isTrue);
      expect(json['instructions'], 'Тренер интервью');
      expect(json['temperature'], isNull);
      final items = (json['input'] as List).map(jsonEncode).toList();

      expect(items, hasLength(3));
      expect(items.join(), isNot(contains('неудачный')));
      expect(items.first, contains('"role":"user"'));
      expect(items.join(), contains('вопрос 2'));
    });

    test('empty system prompt omits instructions', () {
      final request = buildCodexRequest(
        model: 'm',
        systemPrompt: '',
        history: const [],
        prompt: 'привет',
      );
      expect(request.toJson().containsKey('instructions'), isFalse);
    });
  });

  group('CodexChatProvider', () {
    test(
      'streams deltas through local SSE server with codex headers',
      () async {
        final (server, captured) = await startFakeCodexServer();
        final settings = LlmSettings(
          baseUrl: 'http://${server.address.host}:${server.port}/codex',
          model: 'gpt-6-luna',
          apiKey: '',
          authMode: LlmAuthMode.codexDeviceCode,
        );
        final provider = CodexChatProvider(
          settings: settings,
          codexAuth: CodexAuth(
            store: CodexTokenStore(
              storage: MemorySecureStorage()
                ..values['codex.auth'] = encodeTokens(fixedTokens()),
            ),
          ),
          systemPrompt: 'Тренер',
        );
        addTearDown(provider.dispose);

        final chunks = await provider.sendMessageStream('Скажи ок').toList();
        expect(chunks, ['ок']);
        expect(provider.history.map((m) => m.text), ['Скажи ок', 'ок']);

        expect(captured.body, isNotNull);
        expect(captured.body!['store'], isFalse);
        expect(captured.body!['stream'], isTrue);
        expect(captured.body!['instructions'], 'Тренер');
        expect(captured.body!['model'], 'gpt-6-luna');
        expect(captured.body!['input'], isA<List>());
        expect(captured.headers['authorization'], 'Bearer fake.access.token');
        expect(captured.headers['chatgpt-account-id'], 'acc-1');
        expect(captured.headers['originator'], codexOriginator);
        expect(captured.headers['openai-beta'], 'responses=experimental');

        expect(
          captured.headers['host'],
          startsWith('${server.address.host}:${server.port}'),
        );
      },
    );

    test(
      'missing tokens → assistant failed with subscriptionExpired',
      () async {
        const settings = LlmSettings(
          baseUrl: 'http://127.0.0.1:1/codex',
          model: 'gpt-6-luna',
          apiKey: '',
          authMode: LlmAuthMode.codexDeviceCode,
        );
        final provider = CodexChatProvider(
          settings: settings,
          codexAuth: CodexAuth(
            store: CodexTokenStore(storage: MemorySecureStorage()),
          ),
          systemPrompt: '',
        );
        addTearDown(provider.dispose);

        await provider.sendMessageStream('привет').toList();
        final assistant = provider.history.last;
        expect(assistant.failed, isTrue);
        expect(assistant.errorKind, LlmErrorKind.subscriptionExpired);
      },
    );
  });

  group('classifyCodexError', () {
    test('auth exceptions map to subscriptionExpired/connection', () {
      expect(
        classifyCodexError(
          const CodexAuthException(CodexAuthErrorKind.sessionExpired, 'x'),
        ),
        LlmErrorKind.subscriptionExpired,
      );
      expect(
        classifyCodexError(
          const CodexAuthException(CodexAuthErrorKind.rejected, 'x'),
        ),
        LlmErrorKind.connection,
      );
    });

    test('401 text maps to subscriptionExpired', () {
      expect(
        classifyCodexError(Exception('HTTP 401 unauthorized')),
        LlmErrorKind.subscriptionExpired,
      );
    });
  });

  group('CodexAuth.ensureFreshTokens', () {
    test('returns stored tokens while fresh, without network calls', () async {
      final auth = CodexAuth(
        store: CodexTokenStore(
          storage: MemorySecureStorage()
            ..values['codex.auth'] = encodeTokens(fixedTokens()),
        ),
        api: CodexDeviceAuthApi(
          client: MockClient(
            (_) => fail('сеть не должна вызываться при свежих токенах'),
          ),
        ),
      );
      final tokens = await auth.ensureFreshTokens();
      expect(tokens.accountId, 'acc-1');
    });

    test('expired tokens trigger refresh; rotation is persisted', () async {
      final storage = MemorySecureStorage()
        ..values['codex.auth'] = encodeTokens(
          fixedTokens(
            expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        );
      final auth = CodexAuth(
        store: CodexTokenStore(storage: storage),
        api: CodexDeviceAuthApi(
          client: MockClient((request) async {
            expect(request.url.path, '/oauth/token');
            expect(request.body, contains('grant_type=refresh_token'));
            return http.Response(
              jsonEncode(<String, dynamic>{
                'access_token': fakeJwt('acc-refreshed'),
                'refresh_token': 'rt-2',
                'expires_in': 3600,
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      final tokens = await auth.ensureFreshTokens();
      expect(tokens.accountId, 'acc-refreshed');

      final saved = await auth.load();
      expect(saved?.refresh, 'rt-2');
    });

    test('no tokens → sessionExpired', () async {
      final auth = CodexAuth(
        store: CodexTokenStore(storage: MemorySecureStorage()),
        api: CodexDeviceAuthApi(
          client: MockClient((_) => fail('не должно быть сетевых вызовов')),
        ),
      );
      await expectLater(
        auth.ensureFreshTokens(),
        throwsA(
          isA<CodexAuthException>().having(
            (e) => e.kind,
            'kind',
            CodexAuthErrorKind.sessionExpired,
          ),
        ),
      );
    });
  });
}
