# Architecture Decision Records

Short records of the decisions that shape Devmate's architecture. Each ADR is
immutable once accepted: a new decision that reverses an old one gets its own
number referencing the superseded record.

Longer feature design documents live in [`docs/plans/`](../plans/) — ADRs here
capture only the decision and its rationale.

| # | Decision | Status |
|---|----------|--------|
| [0001](0001-state-management-without-frameworks.md) | ChangeNotifier + manual wiring instead of a state-management framework | Accepted |
| [0002](0002-ai-keys-in-secure-storage.md) | AI API keys in flutter_secure_storage, never in backups or bundles | Accepted |
| [0003](0003-design-system-on-flutter-ui-packages.md) | Design system layered on the official `material_ui`/`cupertino_ui` packages | Accepted |
| [0004](0004-generated-localized-question-catalog.md) | Question catalog generated from JSON sources per locale | Accepted |
| [0005](0005-standard-flutter-localization.md) | Standard gen-l10n localization instead of custom solutions | Accepted |
| [0006](0006-backup-envelope-format.md) | Versioned `devmate-backup` envelope without API keys | Accepted |
