import 'package:devmate/data/app_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
  });

  group('AppLanguage', () {
    test('fromCode maps known codes and falls back to system', () {
      expect(AppLanguage.fromCode('ru'), AppLanguage.russian);
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.fromCode(null), AppLanguage.system);
      expect(AppLanguage.fromCode('de'), AppLanguage.system);
    });

    test('locale: system yields null, others yield a locale', () {
      expect(AppLanguage.system.locale, isNull);
      expect(AppLanguage.russian.locale, const Locale('ru'));
      expect(AppLanguage.english.locale, const Locale('en'));
    });
  });

  group('AppPreferencesRepository', () {
    test('defaults to system when nothing is saved', () async {
      final repository = AppPreferencesRepository();
      expect(await repository.loadLanguage(), AppLanguage.system);
    });

    test('saved language reads back', () async {
      final repository = AppPreferencesRepository();
      await repository.saveLanguage(AppLanguage.english);
      expect(await repository.loadLanguage(), AppLanguage.english);
      await repository.saveLanguage(AppLanguage.russian);
      expect(await repository.loadLanguage(), AppLanguage.russian);
    });

    test('system removes the key: after en → system again', () async {
      final repository = AppPreferencesRepository();
      await repository.saveLanguage(AppLanguage.english);
      await repository.saveLanguage(AppLanguage.system);
      expect(await repository.loadLanguage(), AppLanguage.system);
    });
  });

  group('AppThemePreference', () {
    test('fromCode maps known codes and falls back to dark', () {
      expect(AppThemePreference.fromCode('dark'), AppThemePreference.dark);
      expect(AppThemePreference.fromCode('light'), AppThemePreference.light);
      expect(AppThemePreference.fromCode('system'), AppThemePreference.system);
      expect(AppThemePreference.fromCode(null), AppThemePreference.dark);
      expect(AppThemePreference.fromCode('sepia'), AppThemePreference.dark);
    });

    test('mode maps to ThemeMode values', () {
      expect(AppThemePreference.dark.mode, ThemeMode.dark);
      expect(AppThemePreference.light.mode, ThemeMode.light);
      expect(AppThemePreference.system.mode, ThemeMode.system);
    });

    test('defaults to dark when nothing is saved', () async {
      final repository = AppPreferencesRepository();
      expect(await repository.loadTheme(), AppThemePreference.dark);
    });

    test('saved theme reads back', () async {
      final repository = AppPreferencesRepository();
      await repository.saveTheme(AppThemePreference.light);
      expect(await repository.loadTheme(), AppThemePreference.light);
      await repository.saveTheme(AppThemePreference.system);
      expect(await repository.loadTheme(), AppThemePreference.system);
      await repository.saveTheme(AppThemePreference.dark);
      expect(await repository.loadTheme(), AppThemePreference.dark);
    });
  });
}
