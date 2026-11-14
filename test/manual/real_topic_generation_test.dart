import 'dart:io';

import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/topic_draft.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real-provider smoke test: генерация темы по произвольному запросу.
/// Пропускается, если assets/config/.env не содержит ключа.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    HttpOverrides.global = null;
  });

  final envFile = File('assets/config/.env');
  final env = envFile.existsSync() ? envFile.readAsStringSync() : '';
  String value(String key) {
    final match = RegExp('^$key=(.*)\$', multiLine: true).firstMatch(env);
    return match == null ? '' : match.group(1)!.trim();
  }

  test('модель отвечает JSON-темой по свободному запросу', () async {
    final settings = LlmSettings(
      baseUrl: value('LLM_BASE_URL'),
      model: value('LLM_MODEL'),
      apiKey: value('LLM_API_KEY'),
    );
    if (!settings.isConfigured) {
      markTestSkipped('ключ не задан — пропускаем реальную генерацию');
      return;
    }

    final provider = OpenAiCompatibleProvider(
      settings: settings,
      systemPrompt:
          'Ты помогаешь пользователю создавать тренировочные темы для '
          'подготовки к собеседованиям. Отвечай по-русски. Правила: '
          '(1) Если запрос ясен — ответь ровно одним JSON-объектом без '
          'markdown-обёрток и пояснений. Схема объекта: поле title — строка, '
          'название темы; поле description — строка, одно предложение о теме; '
          'поле questions — массив объектов, где каждый объект имеет поле '
          'prompt (вопрос) и поле answer (эталонный ответ в 2-4 предложения). '
          'Вопросов от 4 до 12, вопросы и ответы — на русском. '
          '(2) Если чего-то не хватает для хорошей темы — задай один короткий '
          'уточняющий вопрос обычным текстом, без JSON. '
          '(3) Дополнительный текст рядом с JSON запрещён.',
    );
    final chunks = await provider
        .sendMessageStream('Собери тему «Основы Git» — 4 вопроса')
        .toList();
    final reply = chunks.join();
    debugPrint('=== reply (${reply.length} chars)');

    final draft = parseTopicDraft(reply);
    expect(
      draft,
      isNotNull,
      reason: 'модель не вернула распознаваемый JSON:\n$reply',
    );
    expect(draft!.title?.toLowerCase(), contains('git'));
    expect(draft.questions.length, inInclusiveRange(4, 12));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
