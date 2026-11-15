import 'dart:io';

import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = null;
  });

  final envFile = File('assets/config/.env');
  final settings = _parseEnv(
    envFile.existsSync() ? envFile.readAsStringSync() : '',
  );

  test('real provider streams a reply', () async {
    if (!settings.isConfigured) {
      markTestSkipped(
        'assets/config/.env не задан — пропускаем реальный запрос',
      );
      return;
    }
    final provider = OpenAiCompatibleProvider(
      settings: settings,
      systemPrompt: 'Отвечай по-русски одним словом.',
    );
    final chunks = await provider
        .sendMessageStream('Скажи ровно одно слово: ок')
        .toList();
    final reply = chunks.join();
    debugPrint(
      '=== provider reply (${reply.length} chars): ${reply.trim().substring(0, reply.length.clamp(0, 120))}',
    );
    expect(reply, isNotEmpty);
    expect(reply, isNot(contains('Ошибка')));
  }, timeout: const Timeout(Duration(minutes: 2)));
}

LlmSettings _parseEnv(String source) {
  String value(String key) {
    for (final line in source.split('\n')) {
      final match = RegExp('^$key=(.*)\$').firstMatch(line.trim());
      if (match != null) return match.group(1)!.trim();
    }
    return '';
  }

  return LlmSettings(
    baseUrl: value('LLM_BASE_URL'),
    model: value('LLM_MODEL'),
    apiKey: value('LLM_API_KEY'),
  );
}
