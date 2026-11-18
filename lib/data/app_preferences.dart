import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemePreference {
  dark('dark'),
  light('light'),
  system('system');

  const AppThemePreference(this.code);

  final String code;

  static AppThemePreference fromCode(String? code) =>
      AppThemePreference.values.firstWhere(
        (theme) => theme.code == code,
        orElse: () => AppThemePreference.dark,
      );

  ThemeMode get mode => switch (this) {
    AppThemePreference.dark => ThemeMode.dark,
    AppThemePreference.light => ThemeMode.light,
    AppThemePreference.system => ThemeMode.system,
  };
}

enum AppLanguage {
  system(null),
  russian('ru'),
  english('en');

  const AppLanguage(this.code);

  final String? code;

  static AppLanguage fromCode(String? code) => AppLanguage.values.firstWhere(
    (language) => language.code == code,
    orElse: () => AppLanguage.system,
  );

  Locale? get locale => code == null ? null : Locale(code!);
}

class AppPreferencesRepository {
  AppPreferencesRepository([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const _localeKey = 'app.locale';
  static const _aiDisabledKey = 'app.aiDisabled';
  static const _themeKey = 'app.theme';

  Future<AppLanguage> loadLanguage() async {
    final code = await _preferences.getString(_localeKey);
    return AppLanguage.fromCode(code);
  }

  Future<void> saveLanguage(AppLanguage language) async {
    final code = language.code;
    if (code == null) {
      await _preferences.remove(_localeKey);
    } else {
      await _preferences.setString(_localeKey, code);
    }
  }

  Future<bool> loadAiDisabled() async =>
      await _preferences.getBool(_aiDisabledKey) ?? false;

  Future<void> saveAiDisabled(bool disabled) =>
      _preferences.setBool(_aiDisabledKey, disabled);

  Future<AppThemePreference> loadTheme() async {
    final code = await _preferences.getString(_themeKey);
    return AppThemePreference.fromCode(code);
  }

  Future<void> saveTheme(AppThemePreference theme) =>
      _preferences.setString(_themeKey, theme.code);

  /// Serializable snapshot for a full backup; unknown-safe codes only.
  Future<Map<String, dynamic>> exportBackup() async {
    final theme = await loadTheme();
    final language = await loadLanguage();
    final aiDisabled = await loadAiDisabled();
    return {
      'theme': theme.code,
      if (language.code != null) 'language': language.code,
      'aiDisabled': aiDisabled,
    };
  }

  /// Applies a preferences snapshot from a backup; unknown or malformed
  /// values are ignored so a damaged snapshot keeps the current settings.
  Future<void> restoreBackup(Map<String, dynamic> json) async {
    if (json['theme'] is String) {
      final theme = _themeByCode(json['theme'] as String);
      if (theme != null) await saveTheme(theme);
    }
    if (json['language'] is String) {
      final language = _languageByCode(json['language'] as String);
      if (language != null) await saveLanguage(language);
    }
    if (json['aiDisabled'] is bool) {
      await saveAiDisabled(json['aiDisabled'] as bool);
    }
  }

  static AppThemePreference? _themeByCode(String code) {
    for (final theme in AppThemePreference.values) {
      if (theme.code == code) return theme;
    }
    return null;
  }

  static AppLanguage? _languageByCode(String code) {
    for (final language in AppLanguage.values) {
      if (language.code == code) return language;
    }
    return null;
  }
}
