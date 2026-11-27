import 'dart:convert';

import 'package:devmate/data/chat_tools.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Progress implements ProgressRepository {
  @override
  Future<Map<String, int>> load() async => {'q1': 5};
  @override
  Future<void> save(Map<String, int> scores) async {}
}

void main() {
  final catalog = TopicCatalog(
    baseTopics: [
      const InterviewTopic('t1', 'Dart', 'Language', [
        InterviewQuestion(
          'q1',
          'What is an isolate?',
          'A separate Dart memory heap.',
        ),
      ]),
    ],
  );

  test(
    'local tools read catalog and progress; proposals never write',
    () async {
      final tools = ChatTools(
        catalog: catalog,
        exaKey: '',
        progress: _Progress(),
        allowedEditQuestionId: 'q1',
      );
      addTearDown(tools.dispose);
      expect(
        tools.definitions.map((tool) => tool.function.name),
        contains('get_questions'),
      );
      expect(
        tools.definitions.map((tool) => tool.function.name),
        isNot(contains('search_web')),
      );
      expect(
        jsonDecode(
          await tools.execute('find_questions', '{"query":"isolate"}'),
        ),
        hasLength(1),
      );
      expect(
        jsonDecode(
          await tools.execute('get_topic', '{"topic_id":"t1"}'),
        )['title'],
        'Dart',
      );
      expect(
        jsonDecode(
          await tools.execute('get_questions', '{"topic_id":"t1","offset":0}'),
        )['questions'],
        hasLength(1),
      );
      expect(
        jsonDecode(await tools.execute('get_progress', '{}'))[0]['reviewed'],
        1,
      );
      expect(
        jsonDecode(
          await tools.execute(
            'propose_questions',
            '{"topic":"Dart","questions":[{"prompt":"New question","answer":"New answer"}]}',
          ),
        )['status'],
        'pending_user_confirmation',
      );
      expect(tools.proposedDraft?.questions.single.$1, 'New question');
      expect(
        jsonDecode(
          await tools.execute(
            'propose_answer_edit',
            '{"question_id":"q1","answer":"New"}',
          ),
        )['status'],
        'pending_user_confirmation',
      );
      expect(tools.proposedAnswerUpdate?.answer, 'New');
      tools.resetProposals();
      expect(tools.proposedDraft, isNull);
      expect(tools.proposedAnswerUpdate, isNull);
      expect(
        catalog.topicById('t1')!.questions.single.answer,
        'A separate Dart memory heap.',
      );
      expect(
        jsonDecode(
          await tools.execute('fetch_page', '{"url":"https://example.com"}'),
        )['error'],
        isNotNull,
      );
    },
  );

  test(
    'Exa search authenticates, returns URLs, and only fetches found URLs',
    () async {
      final requests = <String>[];
      final client = MockClient((request) async {
        requests.add(request.url.path);
        expect(request.url.host, 'api.exa.ai');
        expect(request.headers['Authorization'], 'Bearer sample-key');
        if (request.url.path == '/search') {
          expect(jsonDecode(request.body)['type'], 'auto');
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'title': 'Flutter docs',
                  'url': 'https://docs.flutter.dev/',
                  'highlights': ['Official guide'],
                },
              ],
            }),
            200,
          );
        }
        expect(jsonDecode(request.body)['urls'], ['https://docs.flutter.dev/']);
        return http.Response(
          jsonEncode({
            'results': [
              {
                'title': 'Flutter docs',
                'url': 'https://docs.flutter.dev/',
                'text': 'Official documentation',
              },
            ],
          }),
          200,
        );
      });
      final tools = ChatTools(exaKey: 'sample-key', client: client);
      addTearDown(client.close);
      expect(
        jsonDecode(
          await tools.execute('fetch_page', '{"url":"https://other.example/"}'),
        )['error'],
        isNotNull,
      );
      expect(
        jsonDecode(
          await tools.execute('search_web', '{"query":"Flutter"}'),
        )[0]['url'],
        'https://docs.flutter.dev/',
      );
      expect(
        jsonDecode(
          await tools.execute(
            'fetch_page',
            '{"url":"https://docs.flutter.dev/"}',
          ),
        )[0]['text'],
        'Official documentation',
      );
      expect(requests, ['/search', '/contents']);
    },
  );

  test('Brave searches with its key and normalizes results', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.search.brave.com');
      expect(request.url.queryParameters['q'], 'Dart isolates');
      expect(request.headers['X-Subscription-Token'], 'brave-key');
      return http.Response(
        jsonEncode({
          'web': {
            'results': [
              {
                'title': 'Dart',
                'url': 'https://dart.dev/',
                'description': 'Language docs',
              },
            ],
          },
        }),
        200,
      );
    });
    final tools = ChatTools(
      exaKey: '',
      braveKey: 'brave-key',
      searchProvider: 'brave',
      client: client,
    );
    addTearDown(client.close);
    expect(
      tools.definitions.map((t) => t.function.name),
      contains('search_web'),
    );
    expect(
      tools.definitions.map((t) => t.function.name),
      isNot(contains('fetch_page')),
    );
    final result = jsonDecode(
      await tools.execute('search_web', '{"query":"Dart isolates"}'),
    );
    expect(result[0]['url'], 'https://dart.dev/');
  });

  test('Tavily searches with its key and normalizes results', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'api.tavily.com');
      expect(request.headers['Authorization'], 'Bearer tavily-key');
      expect(jsonDecode(request.body)['query'], 'Dart official documentation');
      return http.Response(
        jsonEncode({
          'results': [
            {
              'title': 'Docs',
              'url': 'https://dart.dev/',
              'content': 'Dart docs',
            },
          ],
        }),
        200,
      );
    });
    final tools = ChatTools(
      exaKey: '',
      tavilyKey: 'tavily-key',
      searchProvider: 'tavily',
      client: client,
    );
    addTearDown(client.close);
    final result = jsonDecode(
      await tools.execute('get_documentation', '{"query":"Dart"}'),
    );
    expect(result[0]['text'], 'Dart docs');
  });

  test('Exa failures do not leak credentials into tool output', () async {
    final client = MockClient(
      (_) async => http.Response('invalid secret', 401),
    );
    final tools = ChatTools(exaKey: 'private-key', client: client);
    addTearDown(client.close);
    final result = await tools.execute('search_web', '{"query":"Flutter"}');
    expect(result, contains('HTTP 401'));
    expect(result, isNot(contains('private-key')));
    expect(result, isNot(contains('invalid secret')));
  });
}
