# Security Policy

## Supported versions

Security fixes are made on the latest code in `main` and applied to the most recent release. Older builds are not maintained.

## Reporting a vulnerability

Please report suspected vulnerabilities **privately**, via GitHub's "Report a vulnerability" button on the **Security** tab of this repository. Do not open a public issue for anything you believe is exploitable.

Include, when possible:

- a short description of the issue and its impact,
- steps or a minimal snippet to reproduce it,
- the platform you observed it on (iOS / Android / Web),
- the commit or build you tested.

You will get a response within a few business days. Once a fix is released, credit is optional and yours to choose.

## Scope notes

Devmate is a client-only Flutter app: it has no backend of its own, and AI requests go directly from the device to the provider the user configured. Areas that are in scope for security reports:

- storage of API keys and ChatGPT tokens (`flutter_secure_storage` integration, `lib/data/llm_settings.dart`, `lib/data/codex_token_store.dart`),
- the ChatGPT device-code sign-in flow (`lib/data/codex_auth.dart`),
- parsing of untrusted JSON during topic import/export (`lib/data/topic_catalog.dart`, `lib/data/topic_draft.dart`),
- loading of `assets/config/.env` and key handling on Web (`flutter_secure_storage` uses WebCrypto/LocalStorage in the browser).

Out of scope: provider-side issues (for example, missing CORS headers on a third-party API), and anything requiring a malicious user to already have full access to the device.
