# 0002. AI API keys in secure storage

- **Status:** Accepted
- **Date:** 2026-11

## Context

Devmate talks to OpenAI-compatible APIs directly from the device. The user's
API key must not leak into git, backups, screenshots, or web builds.

## Decision

Keys live in `flutter_secure_storage` (iOS Keychain, Android encrypted
storage, WebCrypto/LocalStorage on web). Debug builds may receive
compile-time defaults via `--dart-define-from-file`, guarded by `kDebugMode`
so release builds ignore them.

The backup envelope (`devmate-backup`) intentionally carries only
`baseUrl`/`model` — never the key. `assets/config/.env` is excluded from Git
and app assets; it exists only for optional manual network tests.

## Consequences

- Restoring a backup on a new device requires re-entering the key — an
  accepted trade-off against leaking secrets into portable files.
- Web keeps keys per browser only; the README documents the CORS story per
  provider instead of promising a proxy.
