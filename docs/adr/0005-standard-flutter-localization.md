# 0005. Standard gen-l10n localization

- **Status:** Accepted
- **Date:** 2026-11

## Context

The app ships in English and Russian, and future languages should not
require rework of a custom string mechanism.

## Decision

Use the standard Flutter localization stack: `flutter_localizations` +
`flutter gen-l10n` with ARB files (`lib/l10n/app_ru.arb` as the template,
`app_en.arb`), plural/placeholder support included.

## Consequences

- Adding a language is one ARB file plus a supportedLocales entry.
- No custom string plumbing to maintain; ICU plurals come for free.
