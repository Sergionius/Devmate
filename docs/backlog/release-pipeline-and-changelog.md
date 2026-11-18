---
worth: yes
priority: p1
where: .github/workflows/ci.yml:1
added: 2026-11-18
---
# release pipeline: build workflow, tags/releases, CHANGELOG

Before opening the repository publicly: add a release workflow (web build to
Pages and/or an Android APK artifact), start tagging versions, and keep a
CHANGELOG. There are currently zero git tags and no build/deploy workflows —
delivery maturity is one of the first things a hiring reviewer checks.

An iOS/TestFlight lane is optional; Android + web cover the demo need.
