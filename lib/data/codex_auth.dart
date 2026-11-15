/// Device-code авторизация в ChatGPT-подписке (Codex backend).
///
/// Намеренно чистый Dart без Flutter-зависимостей: модуль используется и из
/// приложения, и из `tools/codex_device_login_smoke.dart` для e2e-проверки.
///
/// ⚠️ Статус: приватный, недокументированный API OpenAI (превью). Device-флоу
/// работает только для приложений, включённых OpenAI на
/// `/api/accounts/deviceauth/*`. Живая проба (февраль 2026): client_id
/// Codex CLI отвечает `400 invalid_client` («app is unavailable»), client_id
/// клиента pi-coding-agent — работает. Поэтому константа [codexClientId]
/// указывает на регистрацию pi: это экспериментальная опора на чужой
/// «паспорт» и первый шаг до получения собственного client_id (см. анализ
/// Sign in with ChatGPT / dynamic client registration). Формат ответов и
/// заголовков повторяет `openai-codex.js` pi-coding-agent.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart';

/// Публичный client_id OAuth-приложения pi-coding-agent.
const String codexClientId = 'app_EMoamEEZ73f0CkXaXp7hrann';

/// Идентификатор клиента, который сервер Codex backend видит в заголовке
/// `originator`. Должен соответствовать приложению, выдавшему токены.
const String codexOriginator = 'pi';

/// JWT-путь к блоку auth-метаданных в access-токене.
const String codexAccountClaimPath = 'https://api.openai.com/auth';

const String _defaultAuthBaseUrl = 'https://auth.openai.com';

/// Лимит жизни device-кода, как у pi-coding-agent.
const Duration defaultDeviceCodeTimeout = Duration(seconds: 900);

/// Запас до истечения access-токена, раньше которого нужно обновление.
const Duration codexRefreshMargin = Duration(minutes: 5);

/// Код подтверждения, показываемый пользователю, + параметры опроса.
class CodexDeviceCode {
  const CodexDeviceCode({
    required this.deviceAuthId,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
  });

  final String deviceAuthId;

  /// Код вида `XXXX-XXXX`, который пользователь вводит на [verificationUri].
  final String userCode;

  /// Страница, где вводится код: `https://auth.openai.com/codex/device`.
  final String verificationUri;

  /// Пауза между опросами статуса.
  final Duration interval;
}

/// Результат одного опроса статуса авторизации.
sealed class CodexPollResult {
  const CodexPollResult();
}

/// Пользователь ещё не подтвердил вход — продолжать опрос.
class CodexPollPending extends CodexPollResult {
  const CodexPollPending();
}

/// Пользователь подтвердил вход: получены код и верификатор для обмена.
class CodexPollApproved extends CodexPollResult {
  const CodexPollApproved({
    required this.authorizationCode,
    required this.codeVerifier,
  });

  final String authorizationCode;
  final String codeVerifier;
}

/// Опрос завершился ошибкой — вход нужно прервать.
class CodexPollFailed extends CodexPollResult {
  const CodexPollFailed(this.message);

  final String message;
}

enum CodexAuthErrorKind {
  /// Транспорт/сеть: повторная попытка возможна.
  network,

  /// Ответ сервера не соответствует ожидаемой схеме.
  invalidResponse,

  /// Сервер отклонил запрос (включённость приложения, отозванный код).
  rejected,

  /// Пользователь отменил вход или токен-сессия больше не действует.
  sessionExpired,

  /// Код не был подтверждён за отведённое время.
  timeout,
}

class CodexAuthException implements Exception {
  const CodexAuthException(this.kind, this.message);

  final CodexAuthErrorKind kind;
  final String message;

  @override
  String toString() => message;
}

/// Пара токенов подписки; хранится как JSON в secure storage.
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

  /// `chatgpt_account_id` из access-токена; нужен для заголовка
  /// `chatgpt-account-id` в запросах к Codex backend.
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

/// HTTP-клиент device-флоу: код → опрос → обмен → обновление.
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

  /// Запрашивает код подтверждения. Бросает [CodexAuthException]:
  /// [CodexAuthErrorKind.rejected] при отказе сервера (например, приложение
  /// не включено для device-флоу).
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

  /// Один опрос статуса. 403/404 = «ещё не подтверждено», как трактует
  /// pi-coding-agent; сетевой сбой — тоже повод продолжить опрос (одна
  /// потерянная пачка не должна убивать вход — решает дедлайн/отмена).
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

  /// Обмен authorization_code из device-флоу на токены. Верификатор
  /// выдается сервером в ответе опроса (PKCE без нашей стороны).
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

  /// Обновление access-токена; сервер ротирует refresh-токен.
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
      // Отозванный/просроченный refresh-токен: сессия мертва, нужен
      // повторный вход; остальные отказы — разовые ошибки сервера.
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

/// Полный вход: код → пользователь подтверждает в браузере → опрос → обмен.
///
/// [onCode] вызывается один раз, сразу после получения кода, — из него UI
/// показывает [CodexDeviceCode.userCode] и ссылку. [cancel] — отмена
/// пользователем. Бросает [CodexAuthException] с [CodexAuthErrorKind.timeout]
/// ([timeout]), [CodexAuthErrorKind.sessionExpired] при отмене.
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

/// Достаёт `chatgpt_account_id` из payload access-JWT.
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
