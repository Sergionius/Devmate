import 'dart:convert';

import 'package:cross_file/cross_file.dart';

/// Wraps [content] in an in-memory [XFile]; the share_plus web
/// implementation turns it into a Web Share payload or a file download.
Future<XFile> writeJsonShareFile(String fileName, String content) async =>
    XFile.fromData(
      utf8.encode(content),
      mimeType: 'application/json',
      name: fileName,
    );
