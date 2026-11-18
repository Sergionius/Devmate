---
worth: yes
priority: p2
where: integration_test/app_smoke_test.dart:1
added: 2026-11-18
---
# release workflow parked; smoke test is a local pre-release check

Decision (owner, 2026-11-18): no emulator in CI at all — the emulator
pipeline burned 15–45 minutes per run. Push CI
(`.github/workflows/ci.yml`) is the fast green path: format gate, analyze,
catalog freshness, 194 tests, coverage. `integration_test/` stays in the
repo as a LOCAL pre-release check:

    flutter test integration_test

run against an emulator/device before releases and dependency upgrades.

What was already learned and verified, so re-enabling is cheap:
- The release pipeline itself works end to end: web build + APK build were
  green in ~8 min each (runs 44274675014, 44281465253, 44281825490 — the
  later ones for the builds).
- Emulator boot root cause was found and fixed: the runner's disk was too
  full for the AVD userdata partition (`Not enough space to create userdata
  partition`, needs 7.4 GB). Fix: free NDK/dotnet/ghc/CodeQL before boot
  plus the KVM prestep — after that the emulator booted fine (API 34,
  google_apis, x86_64, ubuntu-24.04; "Emulator booted." in run
  44274675014). The API-29 default image never boots there — do not go back
  to it.
- What still fails is the smoke test itself: its home-screen assertions
  (`PICK A TOPIC` / `Frontend`) find nothing on the emulator, reason not yet
  diagnosed. The test dumps visible texts (`HOME TEXTS: …`) into the log —
  the last attempt's diagnosis was cut short.

Re-enable path (owner-approved shape: Pages + APK in releases, no emulator
gate): restore `release.yml` from commit 12fbcbc, drop the android-smoke
job, keep build-web/build-android-apk/create-release, and add a
GitHub Pages deploy job for the web build. Run the smoke test locally
before tagging. CHANGELOG and the first `v1.0.0` tag remain part of this
item.
