import 'dart:async';
import 'dart:convert';

import 'package:devmate/data/codex_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../support/codex_fixtures.dart';

http.Response _json(Object json, [int status = 200]) => http.Response(
  jsonEncode(json),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  group('codexAccountIdFromAccessToken', () {
    test('extracts chatgpt_account_id from payload', () {
      expect(codexAccountIdFromAccessToken(fakeJwt('acc-123')), 'acc-123');
    });

    test('returns null for garbage or missing claim', () {
      expect(codexAccountIdFromAccessToken('not-a-jwt'), isNull);
      // payload '{}' — без claim-пути.
      expect(codexAccountIdFromAccessToken('e30.e30.c2ln'), isNull);
    });
  });

  group('CodexDeviceAuthApi', () {
    test('startDeviceLogin parses code, string interval is accepted', () async {
      late http.Request captured;
      final api = CodexDeviceAuthApi(
        client: MockClient((request) async {
          captured = request;
          return _json(<String, dynamic>{
            'device_auth_id': 'dev-1',
            'user_code': 'ABCD-EFGH',
            'interval': '5',
            'expires_at': '2026-01-01T00:00:00Z',
          });
        }),
      );
      final code = await api.startDeviceLogin();
      expect(code.deviceAuthId, 'dev-1');
      expect(code.userCode, 'ABCD-EFGH');
      expect(code.interval, const Duration(seconds: 5));
      expect(code.verificationUri, 'https://auth.openai.com/codex/device');
      expect(captured.url.path, '/api/accounts/deviceauth/usercode');
      expect(jsonDecode(captured.body), {'client_id': codexClientId});
    });

    test('startDeviceLogin maps server rejection to rejected kind', () async {
      final api = CodexDeviceAuthApi(
        client: MockClient(
          (_) async => _json(<String, dynamic>{
            'error': <String, String>{'code': 'invalid_client'},
          }, 400),
        ),
      );
      await expectLater(
        api.startDeviceLogin(),
        throwsA(
          isA<CodexAuthException>().having(
            (e) => e.kind,
            'kind',
            CodexAuthErrorKind.rejected,
          ),
        ),
      );
    });

    test('startDeviceLogin missing fields → invalidResponse', () async {
      final api = CodexDeviceAuthApi(
        client: MockClient((_) async => _json(<String, String>{'nope': 'x'})),
      );
      await expectLater(
        api.startDeviceLogin(),
        throwsA(
          isA<CodexAuthException>().having(
            (e) => e.kind,
            'kind',
            CodexAuthErrorKind.invalidResponse,
          ),
        ),
      );
    });

    test('pollOnce: 403 pending, 200 approved, 500 failed', () async {
      final responses = <http.Response>[
        http.Response('', 403),
        _json(<String, dynamic>{
          'authorization_code': 'code-1',
          'code_verifier': 'ver-1',
        }),
        http.Response('boom', 500),
      ];
      final api = CodexDeviceAuthApi(
        client: MockClient((request) async {
          expect(request.url.path, '/api/accounts/deviceauth/token');
          expect(jsonDecode(request.body), {
            'device_auth_id': 'dev-1',
            'user_code': 'ABCD-EFGH',
          });
          return responses.removeAt(0);
        }),
      );
      expect(
        await api.pollOnce(deviceAuthId: 'dev-1', userCode: 'ABCD-EFGH'),
        isA<CodexPollPending>(),
      );
      final approved = await api.pollOnce(
        deviceAuthId: 'dev-1',
        userCode: 'ABCD-EFGH',
      );
      expect(
        approved,
        isA<CodexPollApproved>()
            .having((r) => r.authorizationCode, 'code', 'code-1')
            .having((r) => r.codeVerifier, 'verifier', 'ver-1'),
      );
      final failed = await api.pollOnce(
        deviceAuthId: 'dev-1',
        userCode: 'ABCD-EFGH',
      );
      expect(failed, isA<CodexPollFailed>());
    });

    test('pollOnce: network error is transient → keep polling', () async {
      var attempts = 0;
      final api = CodexDeviceAuthApi(
        client: MockClient((request) async {
          attempts++;
          throw Exception('connection reset');
        }),
      );
      final result = await api.pollOnce(
        deviceAuthId: 'dev-1',
        userCode: 'ABCD-EFGH',
      );
      expect(result, isA<CodexPollPending>());
      expect(attempts, 1);
    });

    test('exchangeDeviceCode returns tokens with accountId', () async {
      final api = CodexDeviceAuthApi(
        client: MockClient((request) async {
          expect(request.url.path, '/oauth/token');
          expect(request.url.host, 'auth.openai.com');
          expect(request.body, contains('grant_type=authorization_code'));
          expect(request.body, contains('redirect_uri='));
          return _json(<String, dynamic>{
            'access_token': fakeJwt('acc-42'),
            'refresh_token': 'rt-1',
            'expires_in': 3600,
          });
        }),
      );
      final tokens = await api.exchangeDeviceCode(
        authorizationCode: 'c',
        codeVerifier: 'v',
      );
      expect(tokens.accountId, 'acc-42');
      expect(tokens.refresh, 'rt-1');
      expect(tokens.isExpiringWithin(const Duration(minutes: 5)), isFalse);
    });

    test('refreshTokens: invalid_grant → sessionExpired', () async {
      final api = CodexDeviceAuthApi(
        client: MockClient((request) async {
          expect(request.body, contains('grant_type=refresh_token'));
          return http.Response(
            jsonEncode(<String, String>{'error': 'invalid_grant'}),
            400,
          );
        }),
      );
      await expectLater(
        api.refreshTokens('dead'),
        throwsA(
          isA<CodexAuthException>().having(
            (e) => e.kind,
            'kind',
            CodexAuthErrorKind.sessionExpired,
          ),
        ),
      );
    });

    test('token response missing refresh_token → invalidResponse', () async {
      final api = CodexDeviceAuthApi(
        client: MockClient(
          (_) async => _json(<String, dynamic>{
            'access_token': fakeJwt('acc'),
            'expires_in': 60,
          }),
        ),
      );
      await expectLater(
        api.refreshTokens('rt'),
        throwsA(
          isA<CodexAuthException>().having(
            (e) => e.kind,
            'kind',
            CodexAuthErrorKind.invalidResponse,
          ),
        ),
      );
    });
  });

  group('runCodexDeviceLogin', () {
    test('code → pending → approved → tokens, onCode fired once', () async {
      final events = <String>[];
      final responses = <http.Response>[
        _json(<String, dynamic>{
          'device_auth_id': 'dev-1',
          'user_code': 'XXXX-YYYY',
          'interval': 0,
        }),
        http.Response('', 404),
        _json(<String, dynamic>{
          'authorization_code': 'c',
          'code_verifier': 'v',
        }),
        _json(<String, dynamic>{
          'access_token': fakeJwt('acc-9'),
          'refresh_token': 'rt',
          'expires_in': 3600,
        }),
      ];
      final api = CodexDeviceAuthApi(
        client: MockClient((_) async => responses.removeAt(0)),
      );
      CodexDeviceCode? shown;
      final tokens = await runCodexDeviceLogin(
        api: api,
        onCode: (code) {
          shown = code;
          events.add('code');
        },
      );
      expect(events, ['code']);
      expect(shown?.userCode, 'XXXX-YYYY');
      expect(tokens.accountId, 'acc-9');
    });

    test('cancel completer aborts with sessionExpired', () async {
      final api = CodexDeviceAuthApi(
        client: MockClient(
          (_) async => _json(<String, dynamic>{
            'device_auth_id': 'dev-1',
            'user_code': 'XXXX-YYYY',
            'interval': 0,
          }),
        ),
      );
      final cancel = Completer<void>();
      final future = runCodexDeviceLogin(
        api: api,
        onCode: (_) {},
        cancel: cancel,
      );
      cancel.complete();
      await expectLater(
        future,
        throwsA(
          isA<CodexAuthException>().having(
            (e) => e.kind,
            'kind',
            CodexAuthErrorKind.sessionExpired,
          ),
        ),
      );
    });

    test('unconfirmed code times out', () async {
      final api = CodexDeviceAuthApi(
        client: MockClient((request) async {
          // usercode отдаёт код, любые опросы — «ещё не подтверждено».
          if (request.url.path.endsWith('/usercode')) {
            return _json(<String, dynamic>{
              'device_auth_id': 'dev-1',
              'user_code': 'XXXX-YYYY',
              'interval': 0,
            });
          }
          return http.Response('', 404);
        }),
      );
      await expectLater(
        runCodexDeviceLogin(
          api: api,
          onCode: (_) {},
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(
          isA<CodexAuthException>().having(
            (e) => e.kind,
            'kind',
            CodexAuthErrorKind.timeout,
          ),
        ),
      );
    });
  });
}
