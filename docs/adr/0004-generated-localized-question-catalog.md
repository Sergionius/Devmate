# 0004. Generated localized question catalog

- **Status:** Accepted
- **Date:** 2026-11

## Context

120 questions ship in two locales and must work fully offline, with zero
parsing at startup and no drift between locales.

## Decision

Content sources live in `assets/data/questions{,_en}.json`. A generator
(`tools/generate_catalog.py`, stdlib only) emits
`lib/data/question_catalog.dart` as const Dart data. CI regenerates and fails
if the file drifts (`git diff --exit-code`).

## Consequences

- Startup does zero JSON parsing; tree content is compile-time constants.
- Editing content means editing JSON and running the generator — enforced by
  the CI check, so stale generated files cannot be merged.
