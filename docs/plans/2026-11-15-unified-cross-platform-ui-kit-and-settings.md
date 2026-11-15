<!-- ralphex-base: 0a1875de4cd0239a8eb17235d50b0036766d1553 -->

# Unified cross-platform UI kit and settings for Devmate
<!-- plan-slug: unified-cross-platform-ui-kit-and-settings -->

## Goal

Give iOS, Android, and Web a coherent Devmate visual language while preserving shared colors, typography, and identity. Use platform-appropriate notices, press feedback, dialogs, navigation, and haptics. Split settings into dedicated sections and remove out-of-place elements from chat, JSON import, and question editing without changing business logic.

## Context

- `lib/main.dart` starts one `MaterialApp.router` with a dark theme from `lib/ui/design_system.dart`; screens previously used Material controls with scattered hard-coded colors and spacing.
- `lib/ui/settings_screen.dart` originally combined language, AI provider, JSON import/export, and data reset under the “AI provider (BYOK)” heading. `/settings` is defined in `lib/router.dart`, opened from `home_screen.dart` or `chat_screen.dart`.
- Notices used `ScaffoldMessenger` in chat, practice, topic, edit-topic, and settings screens. Interactive cards used `InkWell`; no explicit `HapticFeedback` calls existed.
- JSON import used `_ImportDialog` in settings; question creation/editing used `AlertDialog` in edit-topic. Import modes and their consequences were already tested in `test/ui/settings_screen_test.dart`.
- Chat used Material loading indicators while loading settings and awaiting a reply. Input and streaming behavior had to be preserved.
- Localization uses `lib/l10n/app_ru.arb` and `lib/l10n/app_en.arb` with Flutter generation. iOS edge-swipe is tested in `test/ui/swipe_back_test.dart`. Project checks include `flutter analyze`, `flutter test`, and `flutter build web`.

## Scope

- Shared semantic visual tokens and small reusable platform-adaptive components; detect platform via `Theme.of(context).platform` and Web via `kIsWeb`.
- iOS: no Material ripple or bottom snackbar; appropriate notices, confirmations, restrained haptics. Android: keep ripple/snackbar where appropriate. Web: hover/focus feedback, keyboard control, desktop-friendly layout without mobile gestures or haptics.
- Separate routes for settings overview, AI provider, and question/data management, with language in general settings. Chat links directly to AI settings.
- Adapt JSON import and question editing to platform and width; retain modes, validation, and operation outcomes.
- Align home, topic, practice, chat, editor, and settings with the same components on compact and wide layouts; replace out-of-place chat loaders with UI-kit indicators.

## Out of Scope

- Changing the JSON format, AI providers, storage, scoring, or question content.
- Replacing the app with `CupertinoApp` or maintaining separate screen codebases per platform.

## Implementation Steps

### Task 1: Shared visual language and adaptive primitives

**Files:**
- Modify: `lib/ui/design_system.dart`
- Create: `lib/ui/platform_ui.dart`
- Create: `test/ui/platform_ui_test.dart`

- [x] Organize existing colors, typography, spacing, shapes, states, and indicators by semantic role without changing product identity; account for contrast, focus, disabled/error states, and text scaling.
- [x] Add compact shared APIs for press feedback, notices, confirmations, and haptics: iOS without ripple/bottom snackbar, Android with ripple/snackbar, Web with hover/focus and keyboard support but no haptics. Avoid haptics for disabled controls, programmatic navigation, or each typed character.
- [x] Define notice presentation and dismissal rules considering `SafeArea`, input overlap, and accessibility; retain success/error feedback after asynchronous operations.
- [x] Widget-test primitives under simulated platforms, including semantics and keyboard activation; leave screen call sites intact during this task.

### Task 2: Split settings and direct navigation to AI

**Files:**
- Modify: `lib/ui/settings_screen.dart`
- Modify: `lib/router.dart`
- Modify: `lib/ui/home_screen.dart`
- Modify: `lib/ui/chat_screen.dart`
- Modify: `lib/l10n/app_ru.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/ui/settings_screen_test.dart`
- Modify: `test/ui/chat_screen_test.dart`

- [x] Split the old screen into `/settings` overview, `/settings/ai` provider, and `/settings/data` questions/data; keep language in general settings. Move controllers and operations to their respective sections while retaining loading, saving, connection testing, the then-existing Codex authorization, import/export, and resets.
- [x] Update `go_router` and call sites: home opens overview; settings from chat and the missing-key CTA open AI settings; returning to chat reloads session settings. Provide clear Web back navigation and retain iOS edge-swipe.
- [x] Update headings and section labels in ARB files; keep standard Flutter localization generation and do not edit generated localization files manually.
- [x] Update settings tests for entry points, saving, language changes, import, reset, and returning to chat.

### Task 3: Platform-appropriate import and edit forms

**Files:**
- Modify: `lib/ui/settings_screen.dart`
- Modify: `lib/ui/edit_topic_screen.dart`
- Modify: `lib/ui/platform_ui.dart`
- Modify: `test/ui/settings_screen_test.dart`
- Create: `test/ui/edit_topic_screen_test.dart`

- [x] Use an adaptive form for JSON input and question creation/editing: an appropriately styled UI-kit sheet on iOS, themed dialog on Android, and width-capped dialog with explicit actions/focus on Web. Support long JSON/answers, keyboard, and text scaling.
- [x] Preserve operation signatures and outcomes: cancellation without changes, append without losing progress, replace with progress reset, required-field validation, and error handling. Retain text after failed import/edit.
- [x] Use the shared platform confirmation contract for deletions/resets without changing meaning or order; test key flows on iOS/Android and wide Web layouts.

## Execution Notes

- `showDevmateForm` in `platform_ui.dart` became an adaptive modal form: an iOS UI-kit bottom sheet with drag handle, keyboard clearance, and scrolling; a themed, scrollable dialog capped at width 600 on Android/Web. `_ImportDialog` now performs import through `onImport` and retains JSON plus inline errors on failure. The screen keeps existing success notices. The question form in `edit_topic_screen.dart` validates fields and save errors inline; form-owned controllers avoid disposal during close animation.
- “Reset progress only,” “Reset everything,” and question deletion use destructive `showDevmateConfirm`; Material confirmation is capped at width 600 on Web/tablets.
- A necessary Task 3 fix: `_EditableQuestionTile` wraps `ListTile` in transparent `Material`. Without it, a new widget test exposed the pre-existing framework assertion “ListTile background color or ink splashes may be invisible.”
- At that milestone: `flutter analyze` clean; `flutter test` passed 156 tests. A one-off `llm_chat_provider_test` failure on the first full run did not reproduce in isolation or on the clean tree and was attributed to a flaky live-network manual test. `flutter build web` succeeded. Device checks for haptics, keyboard, and long JSON were unavailable.

- Task 4, presses: cards and rows (`_FreeChatCard`, `_CreateTopicCard`, `_TopicTile`, question rows, settings overview rows, `_SuggestionCard`, `_SendButton`, editor question tile) use `DevmatePressable`, with selective `selection`/`light` haptics on confirmed actions. Nested controls do not double-trigger haptics. `devmateTheme()` uses `NoSplash.splashFactory` for iOS/macOS, so Material buttons and `IconButton` no longer ripple there; Android/Web remain unchanged.
- Task 4, notices: screens previously using `ScaffoldMessenger`/`SnackBar` (chat, practice, topic, editor, three settings sections, and the then-existing Codex dialog) switched to `showDevmateNotice` with prior text and success/error types. Android retains a themed snackbar; iOS/Web use a nonblocking UI-kit banner.
- Task 4, chat: settings loading uses `DevmateSpinner`; waiting for the first reply fragment uses `DevmateDotsLoader`. Streaming text, disabled input, Enter/Shift+Enter, and error behavior were preserved and tested. Home, AI settings, and the then-existing Codex card also switched to `DevmateSpinner`.
- Task 4, layout: chat/input content is centered and capped at width 760 on wide screens, with bubbles capped at 620. Home topic tile height scales with text, the offline badge compresses, and statistics use `FittedBox`; the 390×844 screen at text scale 1.4 no longer overflows (`test/visual_test.dart` covers home, topic, practice, and chat).
- At that milestone: `flutter analyze` clean; `flutter test` passed 160 tests; `flutter build web` succeeded. Explicitly passed `swipe_back_test`, `settings_screen_test`, `platform_ui_test`, `topic_screen_test`, `practice_discuss_test`, `edit_topic_screen_test`. Manual device checks for haptics, Web keyboard, and on-screen keyboard overlap remained unavailable.

### Task 4: Consistent interactive screen behavior

**Files:**
- Modify: `lib/ui/home_screen.dart`
- Modify: `lib/ui/topic_screen.dart`
- Modify: `lib/ui/practice_screen.dart`
- Modify: `lib/ui/chat_screen.dart`
- Modify: `lib/ui/edit_topic_screen.dart`
- Modify: `lib/ui/settings_screen.dart`
- Modify: `lib/ui/design_system.dart`
- Modify: `test/ui/topic_screen_test.dart`
- Modify: `test/ui/practice_discuss_test.dart`
- Modify: `test/ui/chat_screen_test.dart`
- Modify: `test/visual_test.dart`

- [x] Use shared press states for cards, rows, and primary actions: Android ripple; iOS soft highlight without ripple and restrained haptics on confirmed user actions; Web hover/focus and keyboard activation. Prevent duplicate nested haptics.
- [x] Use one notice API across screens: in-UI notices on iOS, Devmate-colored snackbars on Android, and nonblocking Web notices. Preserve text and success/error distinction.
- [x] Replace Material chat loading indicators (settings loading and waiting for the first response fragment) with UI-kit indicators; retain streaming, disabled input while streaming, Enter/Shift+Enter, and errors.
- [x] Align hierarchy, spacing, content width, and primary actions across listed screens on phone and Web without changing routes, actions, or content. Update widget tests where structure changes; verify no overflows on compact widths and enlarged text.

## Validation

- Run `flutter analyze` and existing `flutter test` after each completed task; run `flutter build web` after routing/Web layout changes.
- Check iOS edge-swipe via `test/ui/swipe_back_test.dart`, settings/import via `test/ui/settings_screen_test.dart`, chat flows, and compact/enlarged-text layout via `test/visual_test.dart`.
- Manually inspect home, topic, practice, chat, three settings sections, import, and question edit on iOS, Android, and Web in loading/success/error states. Check iOS ripple/snackbar absence and restrained device haptics, Web focus/keyboard, notice dismissal, long JSON, software keyboard, and unobstructed input. Compilation/widget tests do not prove haptic feel or visual quality.

## Acceptance Criteria

- All three platforms retain a recognizable Devmate UI kit: no Material ripple or bottom snackbar on iOS; appropriate Material behavior on Android; mouse/keyboard on Web without mobile feedback.
- Settings are split into general, AI, and questions/data; chat opens AI settings directly and picks up changes on return.
- JSON import and question editing feel platform-appropriate; import modes, validation, saving, and reset keep their meaning.
- Chat indicators use the UI kit; reply streaming and input work as before.
- Supported devices have restrained haptics, Web has none, and iOS back gestures plus critical user flows remain intact.
