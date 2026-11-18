import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'transfer_file_writer.dart';

/// Reads the text of a user-picked `.json` file, or `null` when the user
/// cancels the picker. The platform picker covers the iOS Files app
/// (including iCloud Drive), Android storage access framework, and the
/// browser file input on web.
Future<String?> defaultPickJsonFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['json'],
  );
  if (file == null) return null;
  return utf8.decode(await file.readAsBytes());
}

/// Hands a JSON document to the platform share sheet as a file: "Save to
/// Files" (anywhere, including iCloud Drive) on iOS, other apps or Drive on
/// Android, a download on web.
Future<void> defaultShareJsonFile(String fileName, String content) async {
  final file = await writeJsonShareFile(fileName, content);
  await SharePlus.instance.share(ShareParams(files: [file]));
}
