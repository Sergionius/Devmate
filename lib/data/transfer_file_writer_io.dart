import 'dart:io';

import 'package:cross_file/cross_file.dart';

/// Writes [content] to a temporary JSON file and returns it as an [XFile]
/// ready for the platform share sheet.
Future<XFile> writeJsonShareFile(String fileName, String content) async {
  await _removeStaleExportDirs();
  final directory = await Directory.systemTemp.createTemp('devmate_export');
  final file = File('${directory.path}${Platform.pathSeparator}$fileName');
  await file.writeAsString(content, flush: true);
  return XFile(file.path, mimeType: 'application/json');
}

/// Old export files can't be deleted right away (the share sheet may still
/// be reading them), so every new export sweeps leftovers older than a day.
Future<void> _removeStaleExportDirs() async {
  try {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entry in Directory.systemTemp.list()) {
      if (entry is! Directory) continue;
      final name = entry.path.split(Platform.pathSeparator).last;
      if (!name.startsWith('devmate_export')) continue;
      final modified = await entry.stat().then((stat) => stat.modified);
      if (modified.isBefore(cutoff)) {
        await entry.delete(recursive: true);
      }
    }
  } catch (_) {
    // Best-effort cleanup: sharing must not fail because of it.
  }
}
