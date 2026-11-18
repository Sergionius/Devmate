---
worth: yes
priority: p2
where: integration_test/app_smoke_test.dart:1
added: 2026-11-18
---
# release workflow parked: smoke test needs local debugging

The release workflow was removed from the repo on 2026-11-18 (owner call:
CI must stay fast; the emulator pipeline burned 15–45 minutes per run and
kept failing). Push CI (`.github/workflows/ci.yml`) is back to the fast
green path: format gate, analyze, catalog freshness, 194 tests, coverage.

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

Re-enable path: restore `release.yml` from commit 12fbcbc (+ the disk/KVM
steps), run `flutter test integration_test` against a LOCAL Android
emulator (or iOS simulator) until the assertions pass, then bring the
workflow back — gate it on `workflow_dispatch` + `v*` tags only, never on
push. CHANGELOG and the first `v1.0.0` tag remain part of this item.
