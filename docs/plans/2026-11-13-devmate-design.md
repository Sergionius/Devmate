# Devmate — first release

## Goal

Offline technical interview preparation for Frontend, Flutter, iOS, and AI-first developers. The app targets iOS, Android, and Web.

## User flow

The catalog contains ten topics, including architecture, algorithmic complexity, JavaScript / TypeScript, data structures, testing, and system design. Users select a question, write an answer, reveal the reference answer, and assess their own response. If it was inaccurate, they restate it from memory. Each question awards 5 or 10 XP; repeating it cannot inflate the total score but can improve its assessment. Per-topic progress is available.

## Visual direction

A dark developer dashboard with a deep blue-graphite background, light text, a lime accent reserved for the primary action and progress, and lavender for topic icons. Compact letter-spaced captions pair with large question typography. The home screen leads with “Continue training,” followed by actual statistics and the catalog. On narrow screens the sections stack; on wide screens the introduction and progress sit side by side and topics appear in two columns. Transitions are standard, without decorative animation.

## Architecture

Question models are separate from catalog data. `ProgressRepository` encapsulates local `shared_preferences` storage; `TrainingViewModel` handles loading, persistence, and scoring. The UI contains the catalog, topic, and practice screens. Questions ship with the app; no server or account is required. A future AI assessment service could be added without changing the catalog.

## Errors and verification

Empty answers cannot advance. Local read/write errors are shown to users; unconfirmed writes do not count. Tests cover the practice loop, question uniqueness, result persistence, and prevention of XP farming. Static analysis and a Web build verify the app during development.
