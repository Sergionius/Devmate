# Changelog

All notable changes to Devmate are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versions follow [semver](https://semver.org/).

## [1.2.0] - 2026-11-22

### Added

- Vacancy import: paste a job posting, AI turns it into interview questions;
  edit each question inline and save them to a new or an existing topic.
  iOS uses action sheets for the destination picker and the editor dialogs.
- Question chat now opens with the question itself as the first message and
  prefills your draft answer without auto-sending it.

### Changed

- Home header on mobile hides when scrolling down and reappears on scroll up;
  the web layout keeps the static in-content header (smoother web scrolling).
- iOS app bar titles are centered; disabled multiline fields keep the
  rounded border on iOS instead of the Material underline.
- Chat robustness: leaving the chat or opening AI settings mid-stream no
  longer hits disposed sessions; vacancy editor keeps validated drafts.

## [1.1.0] - 2026-11-21

### Added

- Search built-in and custom topics and question prompts, with an optional filter to include reference answers.
- Compile-time LLM defaults can now be used in local release-mode test builds.

### Changed

- Removed the misleading offline badge from the home header.

## [1.0.0] - 2026-11-18

### Added

- 120-question interview catalog in English and Russian, generated from JSON
  sources into compile-time data (10 topics: frontend, Flutter, iOS, AI-first,
  architecture, O(n), JS/TS, algorithms, testing, system design).
- Practice loop: answer in your own words → compare with the reference →
  self-assess; 5/10 XP per question, better score wins, no XP farming.
- Mutable catalog: create and edit topics and questions by hand, generate
  topics with AI chat, append questions to existing topics.
- BYOK AI chat per topic, per question, and free-form: OpenAI-compatible
  providers (z.ai GLM Coding subscription, z.ai, OpenAI, OpenRouter,
  DeepSeek, Groq, Ollama, custom), streaming replies with cancellation,
  chat-drafted topics saved with one tap.
- Full English/Russian localization with in-app language switching.
- Settings: global Disable-AI toggle, full/progress-only/per-topic resets,
  clipboard and file JSON import (replace/append) and export.
- Full backup as a versioned JSON envelope (catalog + progress +
  preferences, never API keys) with replace and merge restore.
- Platform-adaptive UI kit for iOS/Android/Web, light/dark/system themes,
  large-text layout support.
- GitHub Actions CI (format, analyze, tests with coverage, catalog
  freshness), GitHub Pages demo, release workflow with a demo APK,
  integration smoke test.
- Documentation: ARCHITECTURE.md, six ADRs, SECURITY.md, CONTRIBUTING.md.
