import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'codex_auth.dart';

/// Хранилище токенов Codex-подписки: тот же secure storage (iOS Keychain /
/// Android Keystore), что и ключи API.
class CodexTokenStore {
  CodexTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'codex.auth';

  final FlutterSecureStorage _storage;

  Future<CodexTokens?> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return CodexTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Повреждённая запись эквивалентна отсутствию токенов: вход заново.
      return null;
    }
  }

  Future<void> save(CodexTokens tokens) =>
      _storage.write(key: _key, value: jsonEncode(tokens.toJson()));

  Future<void> clear() => _storage.delete(key: _key);
}

/// Фасад над [CodexDeviceAuthApi] и [CodexTokenStore]: выдаёт свежие токены
/// с авто-обновлением (single-flight — параллельные запросы не устраивают
/// гонку за ротирующийся refresh-токен).
class CodexAuth {
  CodexAuth({CodexDeviceAuthApi? api, CodexTokenStore? store})
    : _api = api ?? CodexDeviceAuthApi(),
      _store = store ?? CodexTokenStore();

  /// Экземпляр по умолчанию для UI/чата; тесты создают свои.
  static final CodexAuth shared = CodexAuth();

  final CodexDeviceAuthApi _api;
  final CodexTokenStore _store;

  Completer<CodexTokens>? _refreshing;

  Future<CodexTokens?> load() => _store.load();

  /// Сохраняет токены после успешного [runCodexDeviceLogin].
  Future<void> completeLogin(CodexTokens tokens) => _store.save(tokens);

  /// Локальная очистка. Remote-revocation для этого флоу у OpenAI не
  /// задокументирован, поэтому выход — только локальный; пользователь может
  /// отозвать доступ в настройках ChatGPT.
  Future<void> logout() => _store.clear();

  /// Свежие токены: возвращает сохранённые или обновляет, если истекают
  /// в пределах [margin]. Нет токенов/мёртвый refresh —
  /// [CodexAuthException] c [CodexAuthErrorKind.sessionExpired].
  Future<CodexTokens> ensureFreshTokens({
    Duration margin = codexRefreshMargin,
  }) {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight.future;
    final completer = Completer<CodexTokens>();
    _refreshing = completer;
    _refresh(margin)
        .then(completer.complete, onError: completer.completeError)
        .whenComplete(() => _refreshing = null);
    return completer.future;
  }

  Future<CodexTokens> _refresh(Duration margin) async {
    final tokens = await _store.load();
    if (tokens == null) {
      throw const CodexAuthException(
        CodexAuthErrorKind.sessionExpired,
        'Вход через ChatGPT не выполнен',
      );
    }
    if (!tokens.isExpiringWithin(margin)) return tokens;
    final fresh = await _api.refreshTokens(tokens.refresh);
    await _store.save(fresh);
    return fresh;
  }
}
