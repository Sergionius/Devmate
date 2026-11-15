import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Режим темы интерфейса: тёмная (по умолчанию), светлая или как на
/// устройстве.
enum AppThemePreference {
  dark('dark'),
  light('light'),
  system('system');

  const AppThemePreference(this.code);

  /// Код настройки в хранилище.
  final String code;

  /// Разбирает сохранённый код; неизвестное значение или `null` — тёмная
  /// тема, исторический дефолт продукта.
  static AppThemePreference fromCode(String? code) =>
      AppThemePreference.values.firstWhere(
        (theme) => theme.code == code,
        orElse: () => AppThemePreference.dark,
      );

  /// Значение для [MaterialApp.themeMode].
  ThemeMode get mode => switch (this) {
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.system => ThemeMode.system,
  };
}

/// Язык интерфейса приложения: как в системе или явный выбор ru/en.
enum AppLanguage {
  system(null),
  russian('ru'),
  english('en');

  const AppLanguage(this.code);

  /// BCP-47 код языка; `null` — следовать языку системы.
  final String? code;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (language) => language.code == code,
    orElse: () => AppLanguage.system,
  );

  /// Локаль для [MaterialApp.locale]; `null` означает автоматический выбор
  /// системой.
  Locale? get locale => code == null ? null : Locale(code!);
}

/// Приложенческие настройки, не относящиеся к AI: язык интерфейса и
/// глобальное отключение AI-функций.
class AppPreferencesRepository {
  AppPreferencesRepository([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const _localeKey = 'app.locale';
  static const _aiDisabledKey = 'app.aiDisabled';
  static const _themeKey = 'app.theme';

  /// Возвращает выбранный язык; без сохранённого выбора — [AppLanguage.system].
  Future<AppLanguage> loadLanguage() async {
    final code = await _preferences.getString(_localeKey);
    return AppLanguage.fromCode(code);
  }

  /// Сохраняет язык; для [AppLanguage.system] удаляет ключ, чтобы выбор
  /// продолжал следовать за системной локалью.
  Future<void> saveLanguage(AppLanguage language) async {
    final code = language.code;
    if (code == null) {
      await _preferences.remove(_localeKey);
    } else {
      await _preferences.setString(_localeKey, code);
    }
  }

  /// Включён ли AI; без сохранённого выбора — `false` (AI доступен).
  Future<bool> loadAiDisabled() async =>
      await _preferences.getBool(_aiDisabledKey) ?? false;

  /// Сохраняет глобальное отключение AI.
  Future<void> saveAiDisabled(bool disabled) =>
      _preferences.setBool(_aiDisabledKey, disabled);

  /// Возвращает режим темы; без сохранённого выбора или при неизвестном
  /// значении — тёмная, исторический дефолт продукта.
  Future<AppThemePreference> loadTheme() async {
    final code = await _preferences.getString(_themeKey);
    return AppThemePreference.fromCode(code);
  }

  /// Сохраняет режим темы.
  Future<void> saveTheme(AppThemePreference theme) =>
      _preferences.setString(_themeKey, theme.code);
}
