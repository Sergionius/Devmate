# Architecture

Devmate is an offline trainer for technical interview prep: Flutter
(iOS / Android / Web), Dart ^3.14, Flutter 3.50. It talks to OpenAI-compatible
chat APIs directly from the device; everything else works fully offline.
There are no state-management or dependency-injection frameworks — see
[ADR-0001](docs/adr/0001-state-management-without-frameworks.md).

The short version of every decision that matters lives in
[docs/adr/](docs/adr/README.md); this document maps how the pieces fit together.

## Layers

```
lib/
├── domain/          # pure models: InterviewTopic, InterviewQuestion
├── data/            # repositories, catalogs, AI provider, transfer
│   ├── question_catalog.dart      # generated from assets/data/*.json
│   ├── topic_catalog.dart         # base + user topics, extras, overrides
│   ├── progress_repository.dart   # scores (question id → 5|10)
│   ├── app_preferences.dart       # language, theme, ai-disabled
│   ├── llm_settings.dart          # provider presets + secure storage
│   ├── llm_chat_provider.dart     # openai_dart streaming + error mapping
│   ├── data_transfer.dart         # devmate-backup envelope (v1)
│   └── transfer_*.dart            # share-sheet/file-picker, io/web split
├── ui/              # screens + ChangeNotifier view models
│   ├── design_system.dart         # tokens: colors, spacing, radii, text
│   ├── platform_ui.dart           # adaptive pickers/confirmations/notices
│   ├── home/topic/practice/chat…  # one screen per feature
│   └── training_view_model.dart   # scores state machine
├── l10n/            # flutter gen-l10n, ARB files (ru template + en)
└── router.dart      # go_router, all routes in one place
```

Wiring is manual: `main.dart` builds the repositories, the catalog, and the
view model, then hands them to `DevmateApp` and `createRouter`. No service
locator, no reflection.

## State

- Per-feature `ChangeNotifier` view models: `TrainingViewModel` (scores),
  `ChatViewModel` (in-memory conversation).
- Cross-cutting app state — locale, theme mode, AI-disabled flag — lives in
  plain `ValueNotifier`s constructed in `main()` and passed through
  `DevmateApp` (ADR-0001).
- The catalog serializes writes through an internal mutation queue, so
  concurrent edits (import, user topics, overrides) cannot interleave.

## Data flow

```
assets/data/questions{,_en}.json
        │  tools/generate_catalog.py (CI checks freshness)
        ▼
lib/data/question_catalog.dart          # const Dart data, two locales
        ▼
TopicCatalog (base topics + user topics + extra questions + overrides)
        │  persisted via SharedPreferences (LocalUserTopicsRepository)
        ▼
HomeScreen → TopicScreen → PracticeScreen
        │  self-assessment "knew it" (10 XP) / "reviewed" (5 XP);
        │  repeating never farms points — the better score wins
        ▼
TrainingViewModel → LocalProgressRepository (SharedPreferences)
```

Question content never leaves the device: answers are compared against the
bundled reference, not against a server.

## AI chat (optional)

Per-topic, per-question, and free-form chat screens use `ChatViewModel` →
`LlmChatProvider` (openai_dart, streaming). The provider and key are user
settings: presets (z.ai, OpenAI, OpenRouter, DeepSeek, Groq, Ollama) or a
custom endpoint. Keys live in `flutter_secure_storage`
(ADR-0002) and never leave the device except in requests to the chosen
provider — Devmate has no backend. On web, requests additionally depend on
provider CORS headers; the README documents the verified per-provider matrix.

When a model replies with a JSON topic, the app detects the draft and offers
to save it as a user topic.

## Backup and transfer

The full backup is a versioned envelope (`devmate-backup` v1): catalog +
progress + preferences + AI endpoint — never API keys (ADR-0006). Export
hands the file to the platform share sheet (Files/iCloud Drive on iOS);
import reads through the platform file picker. Replace-restore preserves
topic/question IDs so progress stays valid; merge adds topics and keeps the
better score for questions that already exist on the device.

## Testing

- `test/data` — repositories, catalog mutations (import/restore/merge),
  backup envelope, LLM provider (streaming, cancellation).
- `test/ui` — widget tests per screen and platform-adaptive behavior;
  `test/visual_test.dart` (repo test root) adds large-text and
  compact-viewport checks.
- `integration_test/` — an end-to-end smoke (launch → practice → progress
  saved), run locally against an emulator or device before releases and
  dependency upgrades: `flutter test integration_test`.
- CI (`.github/workflows/ci.yml`): format gate, `flutter analyze`, 194
  tests with a coverage summary artifact, and a generated-catalog freshness
  check. No emulator in CI by decision — the smoke test is a local
  pre-release check (see docs/backlog/release-pipeline-and-changelog.md).

## Decisions

| Topic | ADR |
|---|---|
| State management without frameworks | [ADR-0001](docs/adr/0001-state-management-without-frameworks.md) |
| AI keys in secure storage | [ADR-0002](docs/adr/0002-ai-keys-in-secure-storage.md) |
| Design system on flutter/packages UI libraries | [ADR-0003](docs/adr/0003-design-system-on-flutter-ui-packages.md) |
| Generated localized question catalog | [ADR-0004](docs/adr/0004-generated-localized-question-catalog.md) |
| Standard gen-l10n localization | [ADR-0005](docs/adr/0005-standard-flutter-localization.md) |
| Backup envelope format | [ADR-0006](docs/adr/0006-backup-envelope-format.md) |
