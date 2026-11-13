import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class ProgressRepository {
  Future<Map<String, int>> load();
  Future<void> save(Map<String, int> scores);
}

class LocalProgressRepository implements ProgressRepository {
  LocalProgressRepository(this._preferences);

  static const _key = 'devmate.progress.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<Map<String, int>> load() async {
    final raw = await _preferences.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is int && (entry.value == 5 || entry.value == 10))
            entry.key: entry.value as int,
      };
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> save(Map<String, int> scores) async {
    await _preferences.setString(_key, jsonEncode(scores));
  }
}
