import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Приложенческие настройки, не относящиеся к AI: сейчас — язык интерфейса.
class AppPreferencesRepository {
  AppPreferencesRepository([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const _localeKey = 'app.locale';

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
}
