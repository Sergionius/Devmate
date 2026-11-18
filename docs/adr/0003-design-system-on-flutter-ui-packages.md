# 0003. Design system on the official flutter/packages UI libraries

- **Status:** Accepted
- **Date:** 2026-11

## Context

The app needs a coherent custom look (its own color tokens, spacing, radii,
adaptive iOS/Material behavior). Two routes: style raw SDK widgets, or adopt
the `material_ui`/`cupertino_ui` packages from the official
[flutter/packages](https://github.com/flutter/packages) monorepo, which
Flutter is moving these libraries into.

## Decision

Build on `material_ui` + `cupertino_ui` now, layered with Devmate's own
tokens in `lib/ui/design_system.dart` and adaptive helpers in
`lib/ui/platform_ui.dart` (platform-aware pickers, confirmations, notices,
haptics).

## Consequences

- Early adoption tracks where Flutter is heading; the dependency surface
  stays official rather than third-party.
- Version bumps of the packages are watched by Dependabot; a breaking
  change lands in the token layer, not in every screen.
