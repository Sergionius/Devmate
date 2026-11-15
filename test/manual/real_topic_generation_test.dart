import 'dart:io';

import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/topic_draft.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test(
    'the model replies with a JSON topic from a free-form request',
    () async {
      final settings = LlmSettings(
        baseUrl: value('LLM_BASE_URL'),
        model: value('LLM_MODEL'),
        apiKey: value('LLM_API_KEY'),
      );
      if (!settings.isConfigured) {
        markTestSkipped('key is not set — skipping real generation');
        return;
      }

      final provider = OpenAiCompatibleProvider(
        settings: settings,
        systemPrompt:
            'You help the user create training topics for interview prep. '
            'Reply in English. Rules: '
            '(1) If the request is clear, reply with exactly one JSON object without '
            'markdown wrappers or explanations. Object schema: field title — a string, '
            'the topic name; field description — a string, one sentence about the topic; '
            'field questions — an array of objects where each object has a '
            'prompt field (the question) and an answer field (the reference answer in 2-4 sentences). '
            'From 4 to 12 questions, questions and answers in English. '
            '(2) If anything is missing for a good topic, ask one short '
            'clarifying question in plain text, no JSON. '
            '(3) Extra text next to the JSON is forbidden.',
      );
      final chunks = await provider
          .sendMessageStream('Build a "Git basics" topic — 4 questions')
          .toList();
      final reply = chunks.join();
      debugPrint('=== reply (${reply.length} chars)');

      final draft = parseTopicDraft(reply);
      expect(
        draft,
        isNotNull,
        reason: 'the model did not return recognizable JSON:\n$reply',
      );
      expect(draft!.title?.toLowerCase(), contains('git'));
      expect(draft.questions.length, inInclusiveRange(4, 12));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
