import 'package:devmate/platform/app_environment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('ordinary browser keeps the saved theme', () {
    final environment = BrowserEnvironment();
    addTearDown(environment.dispose);

    expect(environment.isTelegram, isFalse);
    expect(environment.preferredTheme.value, isNull);
    expect(effectiveThemeMode(ThemeMode.dark, null), ThemeMode.dark);
    expect(effectiveThemeMode(ThemeMode.light, null), ThemeMode.light);
  });

  test('host theme overrides the saved preference only in the running app', () {
    expect(
      effectiveThemeMode(ThemeMode.dark, ThemeMode.light),
      ThemeMode.light,
    );
    expect(effectiveThemeMode(ThemeMode.light, ThemeMode.dark), ThemeMode.dark);
  });
}
