import 'dart:convert';

import 'package:devmate/data/data_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> sampleCatalog() => {
    'version': 1,
    'topics': [
      {
        'id': 'topic-1',
        'title': 'Docker',
        'description': 'Containers',
        'questions': [
          {'id': 'q-1', 'prompt': 'What is an image?', 'answer': 'A template.'},
        ],
      },
    ],
  };

  DevmateBackup sampleBackup() => DevmateBackup(
    catalog: sampleCatalog(),
    scores: {'q-1': 10, 'q-2': 5},
    exportedAt: '2026-02-14T10:30:00.000Z',
    preferences: {'theme': 'dark', 'aiDisabled': false},
    ai: {'baseUrl': 'https://api.example.org/v1', 'model': 'test-model'},
  );

  group('DevmateBackup.encode', () {
    test('envelope carries format, version and payload', () {
      final encoded = jsonDecode(sampleBackup().encode());
      expect(encoded, {
        'format': 'devmate-backup',
        'version': 1,
        'exportedAt': '2026-02-14T10:30:00.000Z',
        'catalog': sampleCatalog(),
        'progress': {
          'scores': {'q-1': 10, 'q-2': 5},
        },
        'preferences': {'theme': 'dark', 'aiDisabled': false},
        'ai': {'baseUrl': 'https://api.example.org/v1', 'model': 'test-model'},
      });
    });

    test('omits empty optional sections', () {
      final encoded = jsonDecode(
        DevmateBackup(catalog: sampleCatalog(), scores: const {}).encode(),
      );
      expect(encoded.containsKey('exportedAt'), isFalse);
      expect(encoded.containsKey('preferences'), isFalse);
      expect(encoded.containsKey('ai'), isFalse);
    });
  });

  group('DevmateBackup.parse', () {
    test('round-trips its own encode output', () {
      final backup = DevmateBackup.parse(sampleBackup().encode());
      expect(backup.catalog, sampleCatalog());
      expect(backup.scores, {'q-1': 10, 'q-2': 5});
      expect(backup.exportedAt, '2026-02-14T10:30:00.000Z');
      expect(backup.preferences, {'theme': 'dark', 'aiDisabled': false});
      expect(backup.ai, {
        'baseUrl': 'https://api.example.org/v1',
        'model': 'test-model',
      });
    });

    test('drops invalid progress entries, keeps 5 and 10', () {
      final source = jsonEncode({
        'format': 'devmate-backup',
        'version': 1,
        'catalog': sampleCatalog(),
        'progress': {
          'scores': {'a': 10, 'b': 5, 'c': 7, 'd': '10', '42': 10},
        },
      });
      expect(DevmateBackup.parse(source).scores, {'a': 10, 'b': 5, '42': 10});
    });

    test('tolerates missing progress and optional sections', () {
      final source = jsonEncode({
        'format': 'devmate-backup',
        'version': 1,
        'catalog': sampleCatalog(),
      });
      final backup = DevmateBackup.parse(source);
      expect(backup.scores, isEmpty);
      expect(backup.preferences, isNull);
      expect(backup.ai, isNull);
    });

    test('rejects non-object JSON', () {
      expect(
        () => DevmateBackup.parse('[1, 2]'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Expected a JSON object',
          ),
        ),
      );
    });

    test('rejects malformed JSON', () {
      expect(() => DevmateBackup.parse('{oops'), throwsFormatException);
    });

    test('rejects files with a foreign format', () {
      final source = jsonEncode({
        'format': 'other-app-backup',
        'version': 1,
        'catalog': sampleCatalog(),
      });
      expect(
        () => DevmateBackup.parse(source),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'missing "format": "devmate-backup" marker',
          ),
        ),
      );
    });

    test('rejects versions it cannot read', () {
      final newer = jsonEncode({
        'format': 'devmate-backup',
        'version': 99,
        'catalog': sampleCatalog(),
      });
      expect(() => DevmateBackup.parse(newer), throwsFormatException);
      final missing = jsonEncode({
        'format': 'devmate-backup',
        'catalog': sampleCatalog(),
      });
      expect(() => DevmateBackup.parse(missing), throwsFormatException);
    });

    test('rejects a backup without catalog data', () {
      final source = jsonEncode({'format': 'devmate-backup', 'version': 1});
      expect(() => DevmateBackup.parse(source), throwsFormatException);
    });

    test('ignores non-string ai entries', () {
      final source = jsonEncode({
        'format': 'devmate-backup',
        'version': 1,
        'catalog': sampleCatalog(),
        'ai': {'baseUrl': 5, 'model': 'm'},
      });
      expect(DevmateBackup.parse(source).ai, {'model': 'm'});
    });
  });

  group('mergeScores', () {
    test('keeps the better score per question', () {
      expect(
        mergeScores({'a': 5, 'b': 10, 'c': 5}, {'a': 10, 'b': 5, 'd': 10}),
        {'a': 10, 'b': 10, 'c': 5, 'd': 10},
      );
    });

    test('incoming wins ties and unknown questions pass through', () {
      expect(mergeScores({'a': 5}, {'a': 5}), {'a': 5});
      expect(mergeScores({}, {'n': 10}), {'n': 10});
      expect(mergeScores({'old': 10}, {}), {'old': 10});
    });
  });

  group('transferFileName', () {
    test('builds a sortable file name', () {
      expect(
        transferFileName('devmate-backup', DateTime(2026, 2, 14, 9, 5)),
        'devmate-backup-2026-02-14-0905.json',
      );
    });
  });
}
