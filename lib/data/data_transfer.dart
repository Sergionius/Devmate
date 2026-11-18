import 'dart:convert';

/// Envelope format for a full Devmate backup file: the user topic catalog,
/// training progress, and preferences. API keys are never included — they
/// stay in the platform secret store of each device.
///
/// Envelope layout (version 1):
/// ```json
/// {
///   "format": "devmate-backup",
///   "version": 1,
///   "exportedAt": "2026-02-14T10:30:00.000Z",
///   "catalog": {"version": 1, "topics": [...]},
///   "progress": {"scores": {"<questionId>": 5|10}},
///   "preferences": {"theme": "dark", "language": "ru", "aiDisabled": false},
///   "ai": {"baseUrl": "…", "model": "…"}
/// }
/// ```
class DevmateBackup {
  DevmateBackup({
    required this.catalog,
    required this.scores,
    this.exportedAt,
    Map<String, dynamic>? preferences,
    Map<String, String>? ai,
  }) : preferences = _nonEmpty(preferences),
       ai = _nonEmpty(ai);

  static const formatId = 'devmate-backup';
  static const supportedVersion = 1;

  /// Raw `{"version": 1, "topics": [...]}` catalog payload, ready to feed
  /// into `TopicCatalog.restoreJson` / `TopicCatalog.addJson`.
  final Map<String, dynamic> catalog;

  /// Training progress: question ID → self-assessment score (5 or 10).
  final Map<String, int> scores;

  /// ISO-8601 timestamp of when the backup was created, if provided.
  final String? exportedAt;
  final Map<String, dynamic>? preferences;
  final Map<String, String>? ai;

  static T? _nonEmpty<T extends Map>(T? map) =>
      map == null || map.isEmpty ? null : map;

  String encode() => const JsonEncoder.withIndent('  ').convert({
    'format': formatId,
    'version': supportedVersion,
    if (exportedAt != null) 'exportedAt': exportedAt,
    'catalog': catalog,
    'progress': {'scores': scores},
    if (preferences != null) 'preferences': preferences,
    if (ai != null) 'ai': ai,
  });

  /// Strict about the envelope identity and shape, tolerant about entry
  /// values: malformed progress entries are dropped, unknown keys ignored.
  /// The catalog payload itself is validated later by the catalog layer.
  static DevmateBackup parse(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('Invalid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    if (decoded['format'] != formatId) {
      throw const FormatException('missing "format": "devmate-backup" marker');
    }
    final version = decoded['version'];
    if (version is! int || version < 1 || version > supportedVersion) {
      throw const FormatException('Unsupported backup version');
    }
    final catalog = decoded['catalog'];
    if (catalog is! Map<String, dynamic>) {
      throw const FormatException('Missing catalog data');
    }
    return DevmateBackup(
      catalog: catalog,
      scores: _parseScores(decoded['progress']),
      exportedAt: decoded['exportedAt'] is String
          ? decoded['exportedAt'] as String
          : null,
      preferences: _typedMap(decoded['preferences']),
      ai: _stringMap(decoded['ai']),
    );
  }

  static Map<String, dynamic>? _typedMap(dynamic raw) =>
      raw is Map<String, dynamic> ? raw : null;

  static Map<String, String> _stringMap(dynamic raw) {
    final map = _typedMap(raw);
    if (map == null) return {};
    return {
      for (final entry in map.entries)
        if (entry.value is String) entry.key: entry.value as String,
    };
  }

  static Map<String, int> _parseScores(dynamic raw) {
    final scores = raw is Map<String, dynamic> ? raw['scores'] : null;
    if (scores is! Map) return {};
    return {
      for (final entry in scores.entries)
        if (entry.key is String && (entry.value == 5 || entry.value == 10))
          entry.key as String: entry.value as int,
    };
  }
}

/// Question-level progress merge: the better score wins, matching how the
/// app treats repeated answers to the same question.
Map<String, int> mergeScores(
  Map<String, int> current,
  Map<String, int> incoming,
) {
  final merged = {...current};
  incoming.forEach((id, score) {
    final existing = merged[id];
    if (existing == null || score > existing) merged[id] = score;
  });
  return merged;
}

/// File name for exports, e.g. `devmate-backup-2026-02-14-1030.json`.
String transferFileName(String prefix, DateTime now) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '$prefix-${now.year}-${two(now.month)}-${two(now.day)}'
      '-${two(now.hour)}${two(now.minute)}.json';
}
