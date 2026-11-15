# Devmate

An offline trainer for technical interview prep. A Flutter app for iOS, Android, and Web.

## Features

- 120 questions across 10 topics: Frontend, Flutter, iOS, AI-first, architecture, O(n) complexity, JavaScript / TypeScript, algorithms and data structures, testing, system design. Full content ships in English and Russian.
- Answer in your own words → compare with the reference answer → self-assess. If an answer needs another pass, you restate it before moving on.
- Per-topic progress and XP (5 or 10 per question), stored locally on the device. Repeating a question doesn't farm points; a better self-assessment updates the result.
- Questions are bundled with the app — no account or API required for offline practice. First-time loading of the Web build requires access to the hosted app.
- Your own topics: create and edit topics by hand, save a topic the AI drafted in chat, or import topics as JSON (add or replace). Export copies the catalog to JSON; **Share instruction** gives your AI agent the exact JSON format to fill.
- Interface language: system default, English, or Russian — switched in settings. The UI applies immediately; question content reloads on the next app start.
- AI chat per topic and per question (optional): OpenAI-compatible APIs with streaming replies — presets for ChatGPT Codex (sign in with your ChatGPT subscription via a device code in the browser; iOS/Android only), z.ai GLM Coding (subscription), z.ai API, OpenAI, OpenRouter, DeepSeek, Groq, Ollama — plus a custom endpoint (BYOK). When the model returns a topic as JSON, the app detects it and offers to save it as your own. The chat is built on `openai_dart`; the conversation stays in memory only while its screen is open.

## Getting started

Install the Flutter SDK and run:

```sh
flutter pub get
flutter run -d chrome    # Web
flutter run -d ios       # iOS: requires macOS and Xcode
flutter run -d android   # Android: requires the SDK and an emulator or device
```

Checks: `flutter analyze` and `flutter test`. Web build: `flutter build web`.

## AI chat and keys

On the home screen, open **AI settings**, pick a provider or enter your own OpenAI-compatible **Base URL**, model name, and API key. The "Test connection" button sends a short paid/metered request to the provider. Then open the AI chat from a topic or question screen. Requests go **directly** to the selected provider — Devmate has no server of its own. Settings are stored in `flutter_secure_storage` (iOS Keychain, Android encrypted storage, WebCrypto/LocalStorage in the current browser on web).

Optional initial values can be supplied like this (note: it must be `assets/config/.env` — the app does not read a file placed in the project root):

```sh
cp .env.example assets/config/.env
# Edit assets/config/.env
flutter run
```

If the file is missing or empty, the app starts with empty settings. Saved settings take precedence over `.env`, including a deliberately cleared key. **Never commit `assets/config/.env`: it is excluded from Git. Do not put a real API key into `.env` for a distributable build — especially web: Flutter bundles the asset into the package where any user can read it.** The preferred flow is entering your personal key in the app on the device. Web requires HTTPS (or localhost) for WebCrypto and CORS headers from the API (see the table below); a server without CORS won't work in the browser without your own proxy. For a local HTTP API on Android, cleartext traffic may need to be enabled separately — this build does not enable it.

### CORS on web

A browser can only call APIs that respond with CORS headers. Verified in November 2026:

| Provider | Works on web |
|---|---|
| OpenAI | ✅ |
| OpenRouter | ✅ |
| Groq | ✅ |
| z.ai GLM Coding (subscription) | ✅ iOS/Android, endpoint `api.z.ai/api/coding/paas/v4` |
| z.ai API (pay per token) | ❌ on web; iOS/Android require account balance |
| DeepSeek | ❌ — iOS/Android only |
| Ollama | only with `OLLAMA_ORIGINS=*` |

The GLM Coding Plan subscription works through a separate endpoint, `https://api.z.ai/api/coding/paas/v4`, exposed as the "z.ai GLM Coding (subscription)" preset. The regular `https://api.z.ai/api/paas/v4` charges tokens against your balance and returns error 1113 "Insufficient balance" once it runs out; the app surfaces this as a clear balance message.

On native iOS and Android, all providers work — the limitation is web-only. To use z.ai/DeepSeek in a browser, you need your own proxy server.

Questions live in `assets/data/questions.json` — the single source of truth. After editing the JSON, run `python3 tools/generate_catalog.py` and it will rebuild `lib/data/question_catalog.dart` (the generated file is not meant to be edited by hand). Models are in `lib/domain/`, progress storage in `lib/data/progress_repository.dart`, state and screens in `lib/ui/`. There is no automatic scoring of free-form answers yet: the user compares their answer against the reference on their own.

## Icons

The source image is `assets/branding/devmate_source.png`. After changing it, install Pillow (`python3 -m pip install Pillow`) and run `python3 tools/generate_icons.py`: the script regenerates the iOS icon and the Android icons (regular, adaptive, and monochrome), plus the Web icon, favicon, and the monochrome Android notification icon `@drawable/ic_stat_devmate`. Use this asset as the small icon for local notifications. Push notifications are not set up yet; the Android manifest only carries reserved metadata for a possible future integration.

## Content provenance

All question content — 120 questions in both Russian and English — and the branding artwork (`assets/branding/devmate_source.png`) were created for this project by the author with the help of AI assistants. No third-party copyrighted content is bundled, and everything in `assets/` is covered by the repository license.

## License and contributions

The code and content in this repository are available under the [PolyForm Noncommercial License 1.0.0](LICENSE): you can use, study, modify, and redistribute Devmate for any noncommercial purpose. Bug reports and pull requests are welcome — contributing does not require a commercial license. See [CONTRIBUTING.md](CONTRIBUTING.md) for the developer workflow and [SECURITY.md](SECURITY.md) for private vulnerability reporting.

Commercial use of the code or content (for example, releasing paid or ad-supported apps based on it) is not covered by this license and requires a separate agreement with the author — open an issue to ask.

By opening a pull request, you agree that your contribution may be included in Devmate and used, licensed, and relicensed by the maintainer without restriction, including in commercial releases of the app.
