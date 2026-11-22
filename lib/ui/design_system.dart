import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// Raw Devmate palette. This is the product identity: screens may reference
/// these constants, but new code should prefer the semantic role tokens
/// ([DevmateSpacing], [DevmateRadii], [DevmateStates]) and the themed
/// `ColorScheme`/`TextTheme` so that roles stay interchangeable later.
abstract final class DevmateColors {
  // — Backgrounds —
  /// App background behind all screens.
  static const canvas = Color(0xFF0B1019);

  /// Resting fill of cards and inputs.
  static const surface = Color(0xFF141C29);

  /// Raised fill: bars, dialogs, notifications.
  static const surfaceRaised = Color(0xFF1B2635);

  /// Hairlines, borders, dividers.
  static const border = Color(0xFF2B3849);

  // — Content —
  /// Primary text and icons on [canvas]/[surface].
  static const primary = Color(0xFFF2F5F7);

  /// Secondary text and icons.
  static const muted = Color(0xFF9BA9B8);

  // — Brand accents —
  /// Signature green: primary actions and success states.
  static const accent = Color(0xFFCCF48B);

  /// High-contrast ink used on top of [accent].
  static const accentInk = Color(0xFF182314);

  /// Secondary lavender accent (info, streaming hints).
  static const lavender = Color(0xFFB6B4F9);

  // — Feedback states —
  /// Error foreground (text, icons, destructive fills). Contrast-checked
  /// against [canvas] and [surfaceRaised].
  static const error = Color(0xFFE5766B);

  /// Content placed on top of [error] fills.
  static const onError = Color(0xFF2B0F0D);

  /// Disabled text/icons; paired with [DevmateStates.disabledOpacity].
  static const disabled = Color(0xFF647180);
}

@immutable
class DevmatePalette extends ThemeExtension<DevmatePalette> {
  const DevmatePalette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.primary,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.lavender,
    required this.error,
    required this.onError,
    required this.disabled,
    required this.hoverOverlay,
    required this.pressedOverlay,
    required this.focusOverlay,
    required this.focusRing,
  });

  final Color canvas;

  final Color surface;

  final Color surfaceRaised;

  final Color border;

  final Color primary;

  final Color muted;

  final Color accent;

  final Color accentInk;

  final Color lavender;

  final Color error;

  final Color onError;

  final Color disabled;

  final Color hoverOverlay;

  final Color pressedOverlay;

  final Color focusOverlay;

  final Color focusRing;

  static const DevmatePalette dark = DevmatePalette(
    canvas: DevmateColors.canvas,
    surface: DevmateColors.surface,
    surfaceRaised: DevmateColors.surfaceRaised,
    border: DevmateColors.border,
    primary: DevmateColors.primary,
    muted: DevmateColors.muted,
    accent: DevmateColors.accent,
    accentInk: DevmateColors.accentInk,
    lavender: DevmateColors.lavender,
    error: DevmateColors.error,
    onError: DevmateColors.onError,
    disabled: DevmateColors.disabled,
    hoverOverlay: DevmateStates.hoverOverlay,
    pressedOverlay: DevmateStates.pressedOverlay,
    focusOverlay: DevmateStates.focusOverlay,
    focusRing: DevmateStates.focusRing,
  );

  static const DevmatePalette light = DevmatePalette(
    canvas: Color(0xFFF7F9F6),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF2F6F1),
    border: Color(0xFFC9D3D9),
    primary: Color(0xFF172A24),
    muted: Color(0xFF536474),
    accent: Color(0xFF3D6B27),
    accentInk: Color(0xFFFFFFFF),
    lavender: Color(0xFF5A4BA6),
    error: Color(0xFFB42318),
    onError: Color(0xFFFFFFFF),
    disabled: Color(0xFF8A99A6),
    hoverOverlay: Color(0x14172A24),
    pressedOverlay: Color(0x24172A24),
    focusOverlay: Color(0x403D6B27),
    focusRing: Color(0xFF3D6B27),
  );

  @override
  DevmatePalette lerp(ThemeExtension<DevmatePalette>? other, double t) {
    if (other is! DevmatePalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return DevmatePalette(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceRaised: mix(surfaceRaised, other.surfaceRaised),
      border: mix(border, other.border),
      primary: mix(primary, other.primary),
      muted: mix(muted, other.muted),
      accent: mix(accent, other.accent),
      accentInk: mix(accentInk, other.accentInk),
      lavender: mix(lavender, other.lavender),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
      disabled: mix(disabled, other.disabled),
      hoverOverlay: mix(hoverOverlay, other.hoverOverlay),
      pressedOverlay: mix(pressedOverlay, other.pressedOverlay),
      focusOverlay: mix(focusOverlay, other.focusOverlay),
      focusRing: mix(focusRing, other.focusRing),
    );
  }

  @override
  DevmatePalette copyWith() => this;

  @override
  bool operator ==(Object other) =>
      other is DevmatePalette &&
      other.canvas == canvas &&
      other.surface == surface &&
      other.surfaceRaised == surfaceRaised &&
      other.border == border &&
      other.primary == primary &&
      other.muted == muted &&
      other.accent == accent &&
      other.accentInk == accentInk &&
      other.lavender == lavender &&
      other.error == error &&
      other.onError == onError &&
      other.disabled == disabled &&
      other.hoverOverlay == hoverOverlay &&
      other.pressedOverlay == pressedOverlay &&
      other.focusOverlay == focusOverlay &&
      other.focusRing == focusRing;

  @override
  int get hashCode => Object.hash(
    canvas,
    surface,
    surfaceRaised,
    border,
    primary,
    muted,
    accent,
    accentInk,
    lavender,
    error,
    onError,
    disabled,
    hoverOverlay,
    pressedOverlay,
    focusOverlay,
    focusRing,
  );
}

extension DevmatePaletteContext on BuildContext {
  DevmatePalette get colors {
    final theme = Theme.of(this);
    return theme.extension<DevmatePalette>() ??
        (theme.brightness == Brightness.dark
            ? DevmatePalette.dark
            : DevmatePalette.light);
  }
}

/// Spacing scale. Screens should step through these roles instead of raw
/// pixel numbers so vertical rhythm stays consistent across platforms.
abstract final class DevmateSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  /// Default horizontal page padding for phone layouts.
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: xl);
}

/// Corner radius roles. Value 20 keeps the rounded card identity,
/// 14/16 are the control/field radii already used across screens.
abstract final class DevmateRadii {
  static const double card = 20;
  static const double field = 16;
  static const double control = 14;
  static const double notice = 14;
  static const double sheet = 24;
  static const double pill = 100;

  static final BorderRadius cardBorder = BorderRadius.circular(card);
  static final BorderRadius fieldBorder = BorderRadius.circular(field);
  static final BorderRadius controlBorder = BorderRadius.circular(control);
  static final BorderRadius noticeBorder = BorderRadius.circular(notice);
}

/// Interaction-state tokens: overlays and focus ring derived from the
/// existing palette so hover/pressed/focus stay recognizable but visible.
abstract final class DevmateStates {
  /// Overlay for pointer hover (web/desktop), ~8% primary.
  static const Color hoverOverlay = Color(0x14F2F5F7);

  /// Overlay while pressed, ~14% primary.
  static const Color pressedOverlay = Color(0x24F2F5F7);

  /// Overlay while focused via keyboard, ~25% accent: visible focus ring.
  static const Color focusOverlay = Color(0x40CCF48B);

  /// Solid focus ring color for 2px outlines.
  static const Color focusRing = DevmateColors.accent;
  static const double focusRingWidth = 2;

  /// Content opacity for disabled controls (keeps contrast readable).
  static const double disabledOpacity = 0.45;
}

/// Motion tokens shared by pressable states and transitions.
abstract final class DevmateMotion {
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 200);
  static const Curve emphasized = Curves.easeOutCubic;
}

/// Indicators from the UI kit. Prefer these over raw Material spinners so
/// chat and other screens share one loading language.
abstract final class DevmateIndicators {
  /// Standard round spinner size.
  static const double spinnerSize = 18;
  static const double spinnerStroke = 2;
}

ThemeData devmateTheme() => _devmateTheme(Brightness.dark);

ThemeData devmateLightTheme() => _devmateTheme(Brightness.light);

/// iOS/macOS nav bars keep centered titles; Android and web stay left-aligned.
bool get _appleLikeTitles =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

ThemeData _devmateTheme(Brightness brightness) {
  final palette = brightness == Brightness.dark
      ? DevmatePalette.dark
      : DevmatePalette.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
        surface: palette.surface,
      ).copyWith(
        primary: palette.accent,
        onPrimary: palette.accentInk,
        onSurface: palette.primary,
        onSurfaceVariant: palette.muted,
        outline: palette.border,
        secondary: palette.lavender,
        error: palette.error,
        onError: palette.onError,
      );
  final base = ThemeData(useMaterial3: true, brightness: brightness);
  // iOS/macOS: no Material ink ripple anywhere (cards, rows and buttons
  // alike); the soft dim of DevmatePressable and stationary overlays are
  // the press language there. Android keeps ripple, web keeps ripple plus
  // visible hover/focus overlays.
  final noInkRipple =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);
  return base.copyWith(
    splashFactory: noInkRipple ? NoSplash.splashFactory : null,
    colorScheme: scheme,
    extensions: [palette],
    scaffoldBackgroundColor: palette.canvas,
    disabledColor: palette.disabled,
    dividerColor: palette.border,
    // Subtle brand-tinted interaction overlays instead of default greys.
    hoverColor: palette.hoverOverlay,
    focusColor: palette.focusOverlay,
    splashColor: palette.pressedOverlay,
    highlightColor: palette.hoverOverlay,
    // Headline roles: display titles (large) and screen titles (small).
    textTheme: base.textTheme
        .apply(bodyColor: palette.primary, displayColor: palette.primary)
        .copyWith(
          headlineLarge: TextStyle(
            fontSize: 34,
            height: 1.12,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w800,
            color: palette.primary,
          ),
          headlineSmall: TextStyle(
            fontSize: 25,
            height: 1.2,
            letterSpacing: -0.6,
            fontWeight: FontWeight.w700,
            color: palette.primary,
          ),
          titleLarge: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: palette.primary,
          ),
          // Body roles: main copy (large) and secondary copy (muted, medium).
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: palette.primary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: palette.muted,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.canvas,
      foregroundColor: palette.primary,
      centerTitle: _appleLikeTitles,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: palette.primary,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: DevmateRadii.cardBorder,
        side: BorderSide(color: palette.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: DevmateRadii.cardBorder),
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: palette.primary,
        height: 1.3,
      ),
      contentTextStyle: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: palette.primary,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: DevmateRadii.controlBorder),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 54),
        side: BorderSide(color: palette.border),
        foregroundColor: palette.primary,
        shape: RoundedRectangleBorder(borderRadius: DevmateRadii.controlBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: palette.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: DevmateRadii.fieldBorder,
        borderSide: BorderSide(color: palette.border),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: DevmateRadii.fieldBorder,
        borderSide: BorderSide(color: palette.border),
      ),
      // Visible keyboard focus: accent ring on focused fields.
      focusedBorder: OutlineInputBorder(
        borderRadius: DevmateRadii.fieldBorder,
        borderSide: BorderSide(
          color: palette.focusRing,
          width: DevmateStates.focusRingWidth,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: DevmateRadii.fieldBorder,
        borderSide: BorderSide(color: palette.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: DevmateRadii.fieldBorder,
        borderSide: BorderSide(
          color: palette.error,
          width: DevmateStates.focusRingWidth,
        ),
      ),
      contentPadding: const EdgeInsets.all(20),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.surfaceRaised,
      elevation: 0,
      contentTextStyle: TextStyle(
        color: palette.primary,
        fontSize: 14,
        height: 1.45,
      ),
      actionTextColor: palette.accent,
      closeIconColor: palette.muted,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(
          Radius.circular(DevmateRadii.notice),
        ),
        side: BorderSide(color: palette.border),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.accent,
      linearTrackColor: palette.border,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(palette.border),
      crossAxisMargin: 6,
      mainAxisMargin: 6,
    ),
  );
}

/// Small uppercase section label above content blocks.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.label, {super.key, this.color});
  final String label;

  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      color: color ?? context.colors.accent,
      fontSize: 11,
      letterSpacing: 1.8,
      fontWeight: FontWeight.w800,
    ),
  );
}

/// Linear progress in Devmate styling.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: value,
    minHeight: 5,
    borderRadius: BorderRadius.circular(6),
  );
}

/// Compact round spinner in Devmate colors. Replaces bare
/// [CircularProgressIndicator] call sites on screens.
class DevmateSpinner extends StatelessWidget {
  const DevmateSpinner({super.key, this.size, this.strokeWidth, this.color});

  /// Defaults come from [DevmateIndicators].
  final double? size;
  final double? strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size ?? DevmateIndicators.spinnerSize,
    child: CircularProgressIndicator(
      strokeWidth: strokeWidth ?? DevmateIndicators.spinnerStroke,
      color: color ?? context.colors.accent,
    ),
  );
}

/// Typing-style dots while waiting for the first response fragment.
/// They pulse in sequence; reduced-motion settings show a static pattern.
class DevmateDotsLoader extends StatefulWidget {
  const DevmateDotsLoader({super.key, this.dotSize = 6, this.color});

  final double dotSize;
  final Color? color;

  @override
  State<DevmateDotsLoader> createState() => _DevmateDotsLoaderState();
}

class _DevmateDotsLoaderState extends State<DevmateDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = widget.color ?? context.colors.accent;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++) ...[
            if (index > 0) const SizedBox(width: DevmateSpacing.sm),
            Opacity(
              opacity: reducedMotion
                  ? (1 - index * 0.35)
                  : 0.35 +
                        0.65 *
                            (1 +
                                math.sin(
                                  2 * math.pi * (_controller.value - index / 3),
                                )) /
                            2,
              child: Container(
                width: widget.dotSize,
                height: widget.dotSize,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
