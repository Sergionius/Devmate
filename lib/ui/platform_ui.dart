import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'design_system.dart';

/// Test seam: `kIsWeb` is a compile-time constant that stays `false` under
/// `flutter test`, so widget tests set this flag to exercise the web
/// branches. Never set it in production code.
@visibleForTesting
bool debugDevmateSimulateWeb = false;

bool get _isWeb => kIsWeb || debugDevmateSimulateWeb;

bool _isAppleLike(BuildContext context) {
  if (_isWeb) return false;
  final platform = Theme.of(context).platform;
  return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
}

/// Haptic feedback facade.
///
/// Rules of use (enforced here and by the primitives below):
/// - fire only on direct, confirmed user gestures on enabled controls;
/// - never on disabled controls, programmatic navigation, or per-keystroke
///   input;
/// - no-op on web, where there is no vibration hardware.
abstract final class DevmateHaptics {
  /// Whether haptics can fire on this platform (web: never).
  static bool get available => !_isWeb;

  static void selection() {
    if (available) {
      HapticFeedback.selectionClick();
    }
  }

  static void light() {
    if (available) {
      HapticFeedback.lightImpact();
    }
  }

  static void medium() {
    if (available) {
      HapticFeedback.mediumImpact();
    }
  }

  static void success() {
    if (available) {
      HapticFeedback.successNotification();
    }
  }

  static void warning() {
    if (available) {
      HapticFeedback.warningNotification();
    }
  }

  static void error() {
    if (available) {
      HapticFeedback.errorNotification();
    }
  }

  /// Feedback only after a destructive operation actually completes on iOS.
  static void destructiveActionCompleted(BuildContext context) {
    if (!_isWeb && Theme.of(context).platform == TargetPlatform.iOS) {
      success();
    }
  }
}

/// Haptic strength a [DevmatePressable] may request per user tap.
enum DevmateHapticImpact { none, selection, light, medium }

InputDecoration devmateFieldDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  bool alignLabelWithHint = false,
}) {
  if (_isAppleLike(context)) {
    return InputDecoration(hintText: label);
  }
  return InputDecoration(
    labelText: label,
    hintText: hint,
    alignLabelWithHint: alignLabelWithHint,
  );
}

/// Platform-adaptive tap target.
///
/// - iOS/macOS: no Material ripple; a short soft dim (opacity) marks the
///   press, plus button semantics.
/// - Android/other Material platforms: standard ink ripple clipped to
///   [borderRadius].
/// - Web/desktop pointer environments: visible hover and keyboard-focus
///   overlays; InkWell provides Enter/Space activation when focused.
///
/// The optional [haptic] fires only when the control is enabled and the tap
/// actually happens; disabled controls (no [onTap] or [enabled] false) never
/// trigger it, and on web it is always suppressed.
class DevmatePressable extends StatefulWidget {
  const DevmatePressable({
    super.key,
    required this.onTap,
    required this.child,
    this.enabled = true,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(DevmateRadii.control),
    ),
    this.haptic = DevmateHapticImpact.none,
    this.focusNode,
    this.autofocus = false,
  });

  /// `null` disables the control.
  final VoidCallback? onTap;
  final bool enabled;
  final Widget child;
  final BorderRadius borderRadius;
  final DevmateHapticImpact haptic;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<DevmatePressable> createState() => _DevmatePressableState();
}

class _DevmatePressableState extends State<DevmatePressable> {
  bool _pressed = false;

  bool get _enabled => widget.enabled && widget.onTap != null;

  void _handleTap() {
    if (!_enabled) return;
    switch (widget.haptic) {
      case DevmateHapticImpact.none:
        break;
      case DevmateHapticImpact.selection:
        DevmateHaptics.selection();
      case DevmateHapticImpact.light:
        DevmateHaptics.light();
      case DevmateHapticImpact.medium:
        DevmateHaptics.medium();
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAppleLike(context)) {
      return Semantics(
        button: true,
        enabled: _enabled,
        onTap: _enabled ? _handleTap : null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _enabled ? _handleTap : null,
          onTapDown: _enabled
              ? (_) {
                  if (_pressed) return;
                  setState(() => _pressed = true);
                }
              : null,
          onTapUp: (_) {
            if (!_pressed) return;
            setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (!_pressed) return;
            setState(() => _pressed = false);
          },
          child: AnimatedOpacity(
            opacity: _pressed ? 0.55 : 1,
            duration: DevmateMotion.fast,
            child: widget.child,
          ),
        ),
      );
    }
    // Android + web/desktop: Material ink with visible hover/focus overlays.
    final palette = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _enabled ? _handleTap : null,
        borderRadius: widget.borderRadius,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return palette.focusOverlay;
          }
          if (states.contains(WidgetState.hovered)) {
            return palette.hoverOverlay;
          }
          if (states.contains(WidgetState.pressed)) {
            return palette.pressedOverlay;
          }
          return null;
        }),
        child: widget.child,
      ),
    );
  }
}

/// Severity of a [showDevmateNotice] message.
enum DevmateNoticeKind { success, error, info }

Color _noticeColor(BuildContext context, DevmateNoticeKind kind) =>
    switch (kind) {
      DevmateNoticeKind.success => context.colors.accent,
      DevmateNoticeKind.error => context.colors.error,
      DevmateNoticeKind.info => context.colors.lavender,
    };

IconData _noticeIcon(DevmateNoticeKind kind) => switch (kind) {
  DevmateNoticeKind.success => Icons.check_circle_rounded,
  DevmateNoticeKind.error => Icons.error_outline_rounded,
  DevmateNoticeKind.info => Icons.info_outline_rounded,
};

/// Displaying/closing rules for notifications:
/// - Android: themed floating snackbar at the bottom (Material-appropriate),
///   with an explicit close affordance.
/// - iOS: an in-interface banner at the top under the notch/status bar
///   (`SafeArea`-aware), never a bottom snackbar and never over the input
///   field at the bottom; tap anywhere on the banner to dismiss.
/// - Web: the same top banner but width-capped, non-blocking (content below
///   stays interactive and focus is not stolen).
/// - Success/info auto-dismiss after 3s/4s; errors stay 6s so the text can
///   be read after a failed async operation.
/// - Banners are announced by screen readers (live region) and replace the
///   previous banner instead of stacking.
/// - Safe to call after an async gap as long as the caller checked
///   `context.mounted` (the API re-checks before showing).
OverlayEntry? _activeBanner;

void _dismissActiveBanner() {
  final entry = _activeBanner;
  _activeBanner = null;
  if (entry != null && entry.mounted) entry.remove();
}

/// Removes any active banner; used by tests to avoid leaking timers.
@visibleForTesting
void debugResetDevmateNotifications() => _dismissActiveBanner();

Future<void> showDevmateNotice(
  BuildContext context,
  String message, {
  DevmateNoticeKind kind = DevmateNoticeKind.info,
  Duration? duration,
}) async {
  if (!context.mounted) return;
  final effectiveDuration = duration ?? _defaultNoticeDuration(kind);
  if (!_isAppleLike(context) && !_isWeb) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            duration: effectiveDuration,
            showCloseIcon: true,
            content: Row(
              children: [
                Icon(
                  _noticeIcon(kind),
                  color: _noticeColor(context, kind),
                  size: 20,
                ),
                const SizedBox(width: DevmateSpacing.md),
                Expanded(child: Text(message)),
              ],
            ),
          ),
        );
      return;
    }
  }
  // iOS and web: non-blocking top banner over the root overlay.
  _dismissActiveBanner();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final entry = OverlayEntry(
    builder: (_) => _DevmateBanner(
      message: message,
      kind: kind,
      duration: effectiveDuration,
      onDismiss: _dismissActiveBanner,
    ),
  );
  _activeBanner = entry;
  overlay.insert(entry);
}

Duration _defaultNoticeDuration(DevmateNoticeKind kind) => switch (kind) {
  DevmateNoticeKind.success => const Duration(seconds: 3),
  DevmateNoticeKind.info => const Duration(seconds: 4),
  DevmateNoticeKind.error => const Duration(seconds: 6),
};

class _DevmateBanner extends StatefulWidget {
  const _DevmateBanner({
    required this.message,
    required this.kind,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final DevmateNoticeKind kind;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_DevmateBanner> createState() => _DevmateBannerState();
}

class _DevmateBannerState extends State<_DevmateBanner> {
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _autoDismiss = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _autoDismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _noticeColor(context, widget.kind);
    return Positioned.fill(
      child: SafeArea(
        minimum: const EdgeInsets.all(DevmateSpacing.md),
        child: Align(
          alignment: Alignment.topCenter,
          child: Semantics(
            container: true,
            liveRegion: true,
            child: Material(
              color: context.colors.surfaceRaised,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: DevmateRadii.noticeBorder,
                side: BorderSide(color: color.withValues(alpha: 0.5)),
              ),
              child: GestureDetector(
                onTap: widget.onDismiss,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _isWeb ? 520 : 600),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DevmateSpacing.lg,
                      vertical: DevmateSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_noticeIcon(widget.kind), color: color, size: 20),
                        const SizedBox(width: DevmateSpacing.md),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: TextStyle(
                              color: context.colors.primary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(width: DevmateSpacing.md),
                        Icon(
                          Icons.close_rounded,
                          color: context.colors.muted,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Platform-adaptive modal form used for the JSON import and the
/// create/edit question dialogs.
///
/// - iOS/macOS: a bottom sheet on the raised UI-kit surface with a drag
///   handle and rounded top corners; the content is scrollable and lifted
///   above the keyboard, so long JSON and large text scales stay reachable.
/// - Android: a themed Material dialog consistent with the rest of the app.
/// - Web/desktop: the same themed dialog capped to a reasonable width with
///   explicit action buttons; keyboard focus is driven by the form content
///   (fields may `autofocus`).
///
/// [builder] builds the whole form body: fields, inline validation/error
/// text and the action buttons. The form closes itself with
/// `Navigator.pop(context, value)`; tapping the barrier closes it without a
/// result (cancel without changes) unless [barrierDismissible] is false.
Future<T?> showDevmateForm<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  if (_isAppleLike(context)) {
    return showCupertinoModalPopup<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (sheetContext) => Stack(
        fit: StackFit.expand,
        children: [
          // Fill the exposed rounded corners of the iOS keyboard. Without
          // this, the modal barrier shows through as dark wedges below the
          // raised sheet when the keyboard is visible.
          if (MediaQuery.viewInsetsOf(sheetContext).bottom > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height:
                  MediaQuery.viewInsetsOf(sheetContext).bottom +
                  DevmateRadii.sheet,
              child: ColoredBox(color: context.colors.surfaceRaised),
            ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
                ),
                child: Material(
                  color: context.colors.surfaceRaised,
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(DevmateRadii.sheet),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: DevmateSpacing.sm),
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.colors.border,
                            borderRadius: BorderRadius.circular(
                              DevmateRadii.pill,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          DevmateSpacing.lg,
                          DevmateSpacing.md,
                          DevmateSpacing.lg,
                          0,
                        ),
                        child: Text(
                          title,
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            DevmateSpacing.lg,
                            DevmateSpacing.lg,
                            DevmateSpacing.lg,
                            DevmateSpacing.xl,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              builder(sheetContext),
                              if (MediaQuery.viewInsetsOf(sheetContext)
                                      .bottom ==
                                  0)
                                SizedBox(
                                  height: MediaQuery.viewPaddingOf(sheetContext)
                                      .bottom,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(dialogContext).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: DevmateSpacing.xs),
          child: builder(dialogContext),
        ),
      ),
    ),
  );
}

/// Platform-adaptive confirmation with an explicit affirmative/cancel pair.
///
/// - iOS/macOS: `CupertinoAlertDialog`; the destructive option is rendered in
///   the error color, Cancel is the emphasized default action.
/// - Android/web/desktop: themed Material `AlertDialog`. On web the keyboard
///   focus lands on Cancel for destructive confirms and on Confirm otherwise,
///   so Enter performs the safer action.
/// - Returns `false` when the dialog is dismissed (barrier tap) without an
///   explicit choice.
/// - Confirmation itself never plays a haptic: the caller reports a
///   successful destructive operation after the work actually completes.
Future<bool> showDevmateConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  if (_isAppleLike(context)) {
    final result = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AlertDialog(
      constraints: const BoxConstraints(maxWidth: 600),
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          autofocus: destructive,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          autofocus: !destructive,
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

class DevmateAiVisibility extends StatelessWidget {
  const DevmateAiVisibility({
    super.key,
    required this.aiDisabled,
    this.topGap = EdgeInsets.zero,
    required this.child,
  });

  final ValueListenable<bool>? aiDisabled;

  final EdgeInsetsGeometry topGap;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final listenable = aiDisabled;
    if (listenable == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, disabled, _) =>
          disabled ? SizedBox.shrink() : Padding(padding: topGap, child: child),
    );
  }
}
