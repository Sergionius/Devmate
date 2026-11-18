# 0001. State management without frameworks

- **Status:** Accepted
- **Date:** 2026-11

## Context

Devmate has a small, well-defined state surface: per-question training scores,
a topic catalog, and in-memory AI chat. Popular Flutter setups reach for
Riverpod, BLoC, or Provider to manage this.

## Decision

Use plain `ChangeNotifier` view models (one per feature), `ValueNotifier` for
cross-cutting app state (locale, theme, AI-disabled flag), and manual
dependency wiring in `main.dart`. No state-management or DI packages.

The write-heavy catalog serializes its mutations through an internal
`_enqueueMutation` queue so concurrent writes cannot interleave.

## Consequences

- Zero framework churn; every reader of the code sees exactly what happens.
- New hires need no framework knowledge — only Flutter fundamentals.
- If the app grows large screens with complex async state, revisiting this
  decision (ADR-N replacing this one) is cheaper than carrying a framework
  it does not need today.
