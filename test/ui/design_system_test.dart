import 'package:devmate/ui/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dark theme keeps the historical palette', (tester) async {
    late final ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: devmateTheme(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, DevmateColors.canvas);
    expect(theme.colorScheme.primary, DevmateColors.accent);
    expect(theme.colorScheme.onPrimary, DevmateColors.accentInk);
    expect(theme.colorScheme.error, DevmateColors.error);
    expect(theme.colorScheme.onError, DevmateColors.onError);
    expect(theme.disabledColor, DevmateColors.disabled);
    expect(theme.hoverColor, DevmateStates.hoverOverlay);
    expect(theme.focusColor, DevmateStates.focusOverlay);
    expect(theme.splashColor, DevmateStates.pressedOverlay);
    expect(theme.inputDecorationTheme.fillColor, DevmateColors.surface);
  });

  testWidgets('light theme uses the approved light palette', (tester) async {
    late final ThemeData theme;
    await tester.pumpWidget(
      MaterialApp(
        theme: devmateLightTheme(),
        home: Builder(
          builder: (context) {
            theme = Theme.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final palette = theme.extension<DevmatePalette>()!;
    expect(theme.brightness, Brightness.light);
    expect(palette.canvas, const Color(0xFFF7F9F6));
    expect(palette.surface, Colors.white);
    expect(palette.surfaceRaised, const Color(0xFFF2F6F1));
    expect(palette.primary, const Color(0xFF172A24));
    expect(palette.muted, const Color(0xFF536474));
    expect(palette.border, const Color(0xFFC9D3D9));
    expect(palette.accent, const Color(0xFF3D6B27));
    expect(palette.accentInk, Colors.white);
    expect(palette.lavender, const Color(0xFF5A4BA6));
    expect(palette.error, const Color(0xFFB42318));
    expect(palette.onError, Colors.white);
    expect(palette.focusRing, const Color(0xFF3D6B27));

    expect(theme.scaffoldBackgroundColor, palette.canvas);
    expect(theme.inputDecorationTheme.fillColor, palette.surface);
    expect(theme.colorScheme.primary, palette.accent);
    expect(theme.colorScheme.onPrimary, palette.accentInk);
    expect(theme.appBarTheme.backgroundColor, palette.canvas);
  });

  testWidgets('both themes register the palette for context.colors', (
    tester,
  ) async {
    final theme = devmateTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            expect(context.colors, theme.extension<DevmatePalette>());
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('light theme registers the palette for context.colors', (
    tester,
  ) async {
    final theme = devmateLightTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            expect(context.colors, theme.extension<DevmatePalette>());
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  test('palettes lerp to the other brightness and compare by value', () {
    final mid = DevmatePalette.dark.lerp(DevmatePalette.light, 0.5);
    expect(
      mid.canvas,
      Color.lerp(DevmateColors.canvas, const Color(0xFFF7F9F6), 0.5),
    );
    expect(
      identical(DevmatePalette.dark.copyWith(), DevmatePalette.dark),
      isTrue,
    );
    expect(DevmatePalette.dark, DevmatePalette.dark);
    expect(DevmatePalette.dark == DevmatePalette.light, isFalse);
  });
}
