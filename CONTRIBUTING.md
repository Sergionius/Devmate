# Contributing to Devmate

Thank you for helping improve Devmate! This guide covers the local developer workflow and what to include in a pull request.

## Development setup

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (the project targets Dart `^3.13.7`; see `pubspec.yaml`).
2. Get dependencies:

   ```sh
   flutter pub get
   ```

3. Run the app on your platform of choice:

   ```sh
   flutter run -d chrome    # Web
   flutter run -d ios       # iOS: requires macOS and Xcode
   flutter run -d android   # Android: requires the SDK and an emulator or device
   ```

## Checks

Run both before submitting a PR, and make sure they pass:

```sh
flutter analyze
flutter test
```

The tests in `test/manual/` (`real_llm_smoke_test`, `real_topic_generation_test`) send real requests to an LLM provider. They are skipped automatically when `assets/config/.env` is absent. To run them locally, copy `.env.example` to `assets/config/.env` and fill in your own values — **never commit that file**, it is excluded from Git and is not bundled with the app. If the file is present, `flutter test` also runs these paid/metered requests; remove it or explicitly select the non-manual test paths for offline checks.

## Working with content

- **Questions** live in `assets/data/questions.json` (Russian) and `assets/data/questions_en.json` (English) — the single source of truth. After editing either file, regenerate the catalog:

  ```sh
  python3 tools/generate_catalog.py
  ```

  `lib/data/question_catalog.dart` is generated — do not edit it by hand.
- **Translations** are in `lib/l10n/app_en.arb` (source of truth) and `lib/l10n/app_ru.arb`. Generated localization classes (`lib/l10n/app_localizations*.dart`) update automatically via `flutter gen-l10n` when you run `flutter pub get` (`generate: true` in `pubspec.yaml`).
- **Icons** are generated from `assets/branding/devmate_source.png` by `python3 tools/generate_icons.py` (requires Pillow). Do not edit generated icon assets by hand.

## Pull requests

- Keep one topic per PR; describe what changed and why.
- Keep `flutter analyze` and `flutter test` green.
- PR descriptions are welcome in English or Russian.
- Note that new user-facing strings need both `.arb` files; new question content needs both question JSON files.

## Licensing

Devmate is licensed under the [PolyForm Noncommercial License 1.0.0](LICENSE). By opening a pull request you agree that your contribution may be included in Devmate and used, licensed, and relicensed by the maintainer without restriction, including in commercial releases of the app.

## Security

Do not open public issues for suspected vulnerabilities — see [SECURITY.md](SECURITY.md) for how to report them privately.
