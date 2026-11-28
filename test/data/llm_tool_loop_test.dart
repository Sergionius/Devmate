import 'dart:convert';
import 'dart:io';

import 'package:devmate/data/chat_tools.dart';
import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'tool call executes locally and its result returns to the LLM',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final bodies = <Map<String, dynamic>>[];
      server.listen((request) async {
        final body = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        bodies.add(body);
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf8',
        );
        void chunk(Map<String, dynamic> delta, String? finish) {
          request.response.write(
            'data: ${jsonEncode({
              'id': 'chatcmpl-test',
              'object': 'chat.completion.chunk',
              'created': 1700000000,
              'model': 'test-model',
              'choices': [
                {'index': 0, 'delta': delta, 'finish_reason': finish},
              ],
            })}\n\n',
          );
        }

        if (bodies.length == 1) {
          chunk({
            'role': 'assistant',
            'tool_calls': [
              {
                'index': 0,
                'id': 'call_1',
                'type': 'function',
                'function': {
                  'name': 'find_questions',
                  'arguments': '{"query":"isolate"}',
                },
              },
            ],
          }, null);
          chunk({}, 'tool_calls');
        } else {
          chunk({'content': 'I found the '}, null);
          chunk({'content': 'isolate question.'}, 'stop');
        }
        request.response.write('data: [DONE]\n\n');
        await request.response.close();
      });
      final catalog = TopicCatalog(
        baseTopics: [
          const InterviewTopic('topic', 'Dart', '', [
            InterviewQuestion(
              'question',
              'What is an isolate?',
              'Separate memory.',
            ),
          ]),
        ],
      );
      final provider = OpenAiCompatibleProvider(
        settings: LlmSettings(
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          model: 'test-model',
          apiKey: 'test-key',
        ),
        systemPrompt: 'Help with interview practice',
        tools: ChatTools(catalog: catalog, exaKey: ''),
      );
      addTearDown(provider.dispose);
      final reply = await provider.sendMessageStream('Explain isolates').join();
      expect(reply, 'I found the isolate question.');
      expect(bodies, hasLength(2));
      expect(bodies.first['tools'], isNotEmpty);
      final secondMessages = bodies.last['messages'] as List;
      expect(
        secondMessages[secondMessages.length - 2]['tool_calls'][0]['id'],
        'call_1',
      );
      expect(secondMessages.last['role'], 'tool');
      expect(secondMessages.last['content'], contains('What is an isolate?'));
    },
  );
}
