library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

const String codexClientId = 'app_EMoamEEZ73f0CkXaXp7hrann';

const String codexOriginator = 'pi';

const String codexAccountClaimPath = 'https://api.openai.com/auth';

const String _defaultAuthBaseUrl = 'https://auth.openai.com';

const Duration defaultDeviceCodeTimeout = Duration(seconds: 900);

const Duration codexRefreshMargin = Duration(minutes: 5);

class CodexDeviceCode {
  const CodexDeviceCode({
    required this.deviceAuthId,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
  });

  final String deviceAuthId;

  final String userCode;

  final String verificationUri;

  final Duration interval;
}

sealed class CodexPollResult {
  const CodexPollResult();
}

class CodexPollPending extends CodexPollResult {
  const CodexPollPending();
}

class CodexPollApproved extends CodexPollResult {
  const CodexPollApproved({
    required this.authorizationCode,
    required this.codeVerifier,
  });

  final String authorizationCode;
  final String codeVerifier;
}

class CodexPollFailed extends CodexPollResult {
  const CodexPollFailed(this.message);

  final String message;
}

enum CodexAuthErrorKind {
  network,

  invalidResponse,

  rejected,

  sessionExpired,

  timeout,
}

class CodexAuthException implements Exception {
  const CodexAuthException(this.kind, this.message);

  final CodexAuthErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

class CodexTokens {
  const CodexTokens({
    required this.access,
    required this.refresh,
    required this.expiresAt,
    required this.accountId,
  });

  final String access;
  final String refresh;
  final DateTime expiresAt;

  final String accountId;

  bool isExpiringWithin(Duration margin) =>
      DateTime.now().isAfter(expiresAt.subtract(margin));

  Map<String, dynamic> toJson() => <String, dynamic>{
    'access': access,
    'refresh': refresh,
    'expiresAtMs': expiresAt.millisecondsSinceEpoch,
    'accountId': accountId,
  };

  factory CodexTokens.fromJson(Map<String, dynamic> json) => CodexTokens(
    access: json['access'] as String,
    refresh: json['refresh'] as String,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAtMs'] as int),
    accountId: json['accountId'] as String,
  );
}

class CodexDeviceAuthApi {
  CodexDeviceAuthApi({Client? client, String? authBaseUrl})
    : _client = client ?? Client(),
      _base = (authBaseUrl ?? _defaultAuthBaseUrl).replaceAll(
        RegExp(r'/+$'),
        '',
      );

  final Client _client;
  final String _base;

  Uri get _userCodeUrl => Uri.parse('$_base/api/accounts/deviceauth/usercode');
  Uri get _deviceTokenUrl => Uri.parse('$_base/api/accounts/deviceauth/token');
  Uri get _tokenUrl => Uri.parse('$_base/oauth/token');
  String get _deviceRedirectUri => '$_base/deviceauth/callback';

  Future<CodexDeviceCode> startDeviceLogin() async {
    final Response response;
    try {
      response = await _client.post(
        _userCodeUrl,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{'client_id': codexClientId}),
      );
    } catch (error) {
      throw CodexAuthException(
        CodexAuthErrorKind.network,
        'Не удалось запросить код входа: $error',
      );
    }
    if (response.statusCode != 200) {
      throw CodexAuthException(
        CodexAuthErrorKind.rejected,
        'Сервер отклонил запрос кода (HTTP ${response.statusCode}): '
        '${_short(response.body)}',
      );
    }
    final json = _decodeMap(response.body, 'usercode');
    final deviceAuthId = json['device_auth_id'];
    final userCode = json['user_code'];
    final intervalSeconds = _parseInterval(json['interval']);
    if (deviceAuthId is! String ||
        deviceAuthId.isEmpty ||
        userCode is! String ||
        userCode.isEmpty ||
        intervalSeconds == null) {
      throw CodexAuthException(
        CodexAuthErrorKind.invalidResponse,
        'Неожиданный ответ deviceauth/usercode: ${_short(response.body)}',
      );
    }
    return CodexDeviceCode(
      deviceAuthId: deviceAuthId,
      userCode: userCode,
      verificationUri: '$_base/codex/device',
      interval: Duration(seconds: intervalSeconds),
    );
  }

  Future<CodexPollResult> pollOnce({
    required String deviceAuthId,
    required String userCode,
  }) async {
    final Response response;
    try {
      response = await _client.post(
        _deviceTokenUrl,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(<String, String>{
          'device_auth_id': deviceAuthId,
          'user_code': userCode,
        }),
      );
    } catch (_) {
      return const CodexPollPending();
    }
    if (response.statusCode == 403 || response.statusCode == 404) {
      return const CodexPollPending();
    }
    if (response.statusCode != 200) {
      return CodexPollFailed(
        'Опрос статуса не удался (HTTP ${response.statusCode}): '
        '${_short(response.body)}',
      );
    }
    final json = _decodeMap(response.body, 'deviceauth/token');
    final code = json['authorization_code'];
    final verifier = json['code_verifier'];
    if (code is! String ||
        code.isEmpty ||
        verifier is! String ||
        verifier.isEmpty) {
      return CodexPollFailed(
        'Неожиданный ответ deviceauth/token: ${_short(response.body)}',
      );
    }
    return CodexPollApproved(authorizationCode: code, codeVerifier: verifier);
  }

  Future<CodexTokens> exchangeDeviceCode({
    required String authorizationCode,
    required String codeVerifier,
  }) => _postToken(<String, String>{
    'grant_type': 'authorization_code',
    'client_id': codexClientId,
    'code': authorizationCode,
    'code_verifier': codeVerifier,
    'redirect_uri': _deviceRedirectUri,
  });

  Future<CodexTokens> refreshTokens(String refreshToken) =>
      _postToken(<String, String>{
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': codexClientId,
      });

  Future<CodexTokens> _postToken(Map<String, String> form) async {
    final Response response;
    try {
      response = await _client.post(
        _tokenUrl,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: form,
      );
    } catch (error) {
      throw CodexAuthException(
        CodexAuthErrorKind.network,
        'Ошибка сети при обмене токенов: $error',
      );
    }
    if (response.statusCode != 200) {
      final body = _short(response.body);

      final expired =
          response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.body.contains('invalid_grant');
      throw CodexAuthException(
        expired
            ? CodexAuthErrorKind.sessionExpired
            : CodexAuthErrorKind.rejected,
        'Обмен токенов не удался (HTTP ${response.statusCode}): $body',
      );
    }
    final json = _decodeMap(response.body, 'token');
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final expiresIn = json['expires_in'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        expiresIn is! num) {
      throw CodexAuthException(
        CodexAuthErrorKind.invalidResponse,
        'Неожиданный ответ oauth/token: ${_short(response.body)}',
      );
    }
    final accountId = codexAccountIdFromAccessToken(access);
    if (accountId == null) {
      throw CodexAuthException(
        CodexAuthErrorKind.invalidResponse,
        'В access-токене нет chatgpt_account_id',
      );
    }
    return CodexTokens(
      access: access,
      refresh: refresh,
      expiresAt: DateTime.now().add(
        Duration(milliseconds: (expiresIn * 1000).round()),
      ),
      accountId: accountId,
    );
  }

  Map<String, dynamic> _decodeMap(String body, String step) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    throw CodexAuthException(
      CodexAuthErrorKind.invalidResponse,
      'Ответ $step не является JSON-объектом: ${_short(body)}',
    );
  }

  static int? _parseInterval(Object? value) {
    if (value is num && value >= 0) return value.round();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
  }

  static String _short(String body) {
    final trimmed = body.trim();
    return trimmed.length <= 200 ? trimmed : '${trimmed.substring(0, 200)}…';
  }
}

Future<CodexTokens> runCodexDeviceLogin({
  required CodexDeviceAuthApi api,
  required void Function(CodexDeviceCode code) onCode,
  Completer<void>? cancel,
  Duration timeout = defaultDeviceCodeTimeout,
}) async {
  final device = await api.startDeviceLogin();
  onCode(device);
  final deadline = DateTime.now().add(timeout);
  while (true) {
    if (cancel != null && cancel.isCompleted) {
      throw const CodexAuthException(
        CodexAuthErrorKind.sessionExpired,
        'Вход отменён',
      );
    }
    if (DateTime.now().isAfter(deadline)) {
      throw const CodexAuthException(
        CodexAuthErrorKind.timeout,
        'Код не был подтверждён за отведённое время',
      );
    }
    final CodexPollResult result = await api.pollOnce(
      deviceAuthId: device.deviceAuthId,
      userCode: device.userCode,
    );
    switch (result) {
      case CodexPollApproved(:final authorizationCode, :final codeVerifier):
        return api.exchangeDeviceCode(
          authorizationCode: authorizationCode,
          codeVerifier: codeVerifier,
        );
      case CodexPollPending():
        await Future<void>.delayed(device.interval);
      case CodexPollFailed(:final message):
        throw CodexAuthException(CodexAuthErrorKind.rejected, message);
    }
  }
}

String? codexAccountIdFromAccessToken(String accessToken) {
  final parts = accessToken.split('.');
  if (parts.length != 3) return null;
  try {
    var payload = parts[1];
    payload += '=' * ((4 - payload.length % 4) % 4);
    final claims = jsonDecode(utf8.decode(base64Url.decode(payload)));
    if (claims is! Map<String, dynamic>) return null;
    final auth = claims[codexAccountClaimPath];
    if (auth is! Map<String, dynamic>) return null;
    final accountId = auth['chatgpt_account_id'];
    return accountId is String && accountId.isNotEmpty ? accountId : null;
  } catch (_) {
    return null;
  }
}
