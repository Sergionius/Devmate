import 'package:flutter/material.dart';

abstract final class DevmateColors {
  static const canvas = Color(0xFF0B1019);
  static const surface = Color(0xFF141C29);
  static const surfaceRaised = Color(0xFF1B2635);
  static const border = Color(0xFF2B3849);
  static const primary = Color(0xFFF2F5F7);
  static const muted = Color(0xFF9BA9B8);
  static const accent = Color(0xFFCCF48B);
  static const accentInk = Color(0xFF182314);
  static const lavender = Color(0xFFB6B4F9);
}

ThemeData devmateTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: DevmateColors.accent,
        brightness: Brightness.dark,
        surface: DevmateColors.surface,
      ).copyWith(
        primary: DevmateColors.accent,
        onPrimary: DevmateColors.accentInk,
        onSurface: DevmateColors.primary,
        outline: DevmateColors.border,
        secondary: DevmateColors.lavender,
      );
  final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: DevmateColors.canvas,
    textTheme: base.textTheme
        .apply(
          bodyColor: DevmateColors.primary,
          displayColor: DevmateColors.primary,
        )
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 34,
            height: 1.12,
            letterSpacing: -1.5,
            fontWeight: FontWeight.w800,
            color: DevmateColors.primary,
          ),
          headlineSmall: const TextStyle(
            fontSize: 25,
            height: 1.2,
            letterSpacing: -0.6,
            fontWeight: FontWeight.w700,
            color: DevmateColors.primary,
          ),
          titleLarge: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: DevmateColors.primary,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: DevmateColors.primary,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 1.5,
            color: DevmateColors.muted,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DevmateColors.canvas,
      foregroundColor: DevmateColors.primary,
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: DevmateColors.primary,
      ),
    ),
    cardTheme: CardThemeData(
      color: DevmateColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DevmateColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 54),
        side: const BorderSide(color: DevmateColors.border),
        foregroundColor: DevmateColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DevmateColors.surface,
      hintStyle: const TextStyle(color: DevmateColors.muted),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DevmateColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DevmateColors.accent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(20),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: DevmateColors.accent,
      linearTrackColor: DevmateColors.border,
    ),
    scrollbarTheme: const ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(DevmateColors.border),
      crossAxisMargin: 6,
      mainAxisMargin: 6,
    ),
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.label, {super.key, this.color = DevmateColors.accent});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      color: color,
      fontSize: 11,
      letterSpacing: 1.8,
      fontWeight: FontWeight.w800,
    ),
  );
}

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
