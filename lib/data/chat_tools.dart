import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openai_dart/openai_dart.dart' as oai;
import 'package:shared_preferences/shared_preferences.dart';

import 'progress_repository.dart';
import 'topic_catalog.dart';

/// Read-only context and proposal tools. No tool writes user data.
class ChatTools {
  ChatTools({
    this.catalog,
    required this.exaKey,
    this.braveKey = '',
    this.tavilyKey = '',
    this.searchProvider = 'exa',
    http.Client? client,
    this._progress,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null;

  final TopicCatalog? catalog;
  final String exaKey;
  final String braveKey;
  final String tavilyKey;
  final String searchProvider;
  String get _searchKey => switch (searchProvider) {
    'brave' => braveKey,
    'tavily' => tavilyKey,
    _ => exaKey,
  };
  final http.Client _client;
  final bool _ownsClient;
  final ProgressRepository? _progress;
  final Set<String> _foundUrls = {};

  static oai.Tool _tool(
    String name,
    String description,
    Map<String, dynamic> properties,
    List<String> required,
  ) => oai.Tool.function(
    name: name,
    description: description,
    parameters: {
      'type': 'object',
      'properties': properties,
      'required': required,
    },
  );

  static const _string = {'type': 'string'};

  List<oai.Tool> get definitions => [
    if (catalog != null) ...[
      _tool(
        'find_questions',
        'Search the local interview question catalog by keyword.',
        {'query': _string},
        ['query'],
      ),
      _tool(
        'get_topic',
        'Read a local topic and its questions and answers by topic ID.',
        {'topic_id': _string},
        ['topic_id'],
      ),
      _tool(
        'get_progress',
        'Read local training scores and identify topics to review.',
        {},
        [],
      ),
      _tool(
        'propose_questions',
        'Propose interview questions for user review; never saves them.',
        {
          'topic': _string,
          'questions': {'type': 'array', 'items': _string},
        },
        ['topic', 'questions'],
      ),
      _tool(
        'propose_answer_edit',
        'Propose an answer edit for user review; never saves it.',
        {'question_id': _string, 'answer': _string},
        ['question_id', 'answer'],
      ),
    ],
    if (_searchKey.trim().isNotEmpty) ...[
      _tool(
        'search_web',
        'Search the current web. Cite result URLs in the answer.',
        {'query': _string},
        ['query'],
      ),
      _tool(
        'get_documentation',
        'Find current official documentation with Exa. Cite source URLs.',
        {'query': _string},
        ['query'],
      ),
      if (exaKey.trim().isNotEmpty)
        _tool(
          'fetch_page',
          'Read a page returned by search_web or get_documentation using Exa.',
          {'url': _string},
          ['url'],
        ),
    ],
  ];

  Future<String> execute(String name, String rawArguments) async {
    try {
      final value = jsonDecode(rawArguments);
      if (value is! Map<String, dynamic>) return _error('Invalid arguments');
      String argument(String key) =>
          (value[key] is String ? value[key] as String : '').trim();
      switch (name) {
        case 'find_questions':
          final query = argument('query').toLowerCase();
          if (catalog == null || query.length < 2) {
            return _error('Query must contain at least 2 characters');
          }
          return jsonEncode(
            [
              for (final topic in catalog!.topics)
                for (final question in topic.questions)
                  if ('${question.prompt} ${question.answer}'
                      .toLowerCase()
                      .contains(query))
                    {
                      'topic_id': topic.id,
                      'topic': topic.title,
                      'question_id': question.id,
                      'question': question.prompt,
                      'answer': _limit(question.answer, 1000),
                    },
            ].take(12).toList(),
          );
        case 'get_topic':
          final topic = catalog?.topicById(argument('topic_id'));
          if (topic == null) return _error('Topic not found');
          return jsonEncode({
            'id': topic.id,
            'title': topic.title,
            'description': topic.description,
            'questions': [
              for (final q in topic.questions.take(30))
                {
                  'id': q.id,
                  'question': q.prompt,
                  'answer': _limit(q.answer, 1000),
                },
            ],
          });
        case 'get_progress':
          if (catalog == null) return _error('Catalog unavailable');
          final scores =
              await (_progress ??
                      LocalProgressRepository(SharedPreferencesAsync()))
                  .load();
          return jsonEncode([
            for (final topic in catalog!.topics)
              {
                'topic_id': topic.id,
                'title': topic.title,
                'total': topic.questions.length,
                'completed': topic.questions
                    .where((q) => scores.containsKey(q.id))
                    .length,
                'reviewed': topic.questions
                    .where((q) => scores[q.id] == 5)
                    .length,
              },
          ]);
        case 'propose_questions':
          if (catalog == null) return _error('Catalog unavailable');
          final questions = value['questions'];
          if (argument('topic').isEmpty ||
              questions is! List ||
              questions.isEmpty ||
              questions.length > 20 ||
              questions.any((q) => q is! String || q.length > 500)) {
            return _error('Invalid proposal');
          }
          return jsonEncode({
            'status': 'proposal_only',
            'topic': argument('topic'),
            'questions': questions,
            'message':
                'Show this proposal to the user. Nothing has been saved.',
          });
        case 'propose_answer_edit':
          if (catalog == null) return _error('Catalog unavailable');
          final id = argument('question_id');
          if (!catalog!.topics.any((t) => t.questions.any((q) => q.id == id)) ||
              argument('answer').isEmpty ||
              argument('answer').length > 6000) {
            return _error('Invalid proposal');
          }
          return jsonEncode({
            'status': 'proposal_only',
            'question_id': id,
            'answer': argument('answer'),
            'message':
                'Show this proposal to the user. Nothing has been saved.',
          });
        case 'search_web':
        case 'get_documentation':
          final query = argument('query');
          if (query.isEmpty || query.length > 300) {
            return _error('Invalid query');
          }
          final searchQuery = name == 'get_documentation'
              ? '$query official documentation'
              : query;
          return switch (searchProvider) {
            'brave' => await _brave(searchQuery),
            'tavily' => await _tavily(searchQuery),
            _ => await _exa('/search', {
              'query': searchQuery,
              'type': 'auto',
              'numResults': 5,
              'contents': {'highlights': true},
            }),
          };
        case 'fetch_page':
          final url = argument('url');
          if (exaKey.trim().isEmpty || !_foundUrls.contains(url)) {
            return _error('Search for this URL first and configure Exa');
          }
          return await _exa('/contents', {
            'urls': [url],
            'text': {'maxCharacters': 8000},
          });
        default:
          return _error('Unknown tool');
      }
    } catch (_) {
      return _error('Tool unavailable or request failed');
    }
  }

  Future<String> _brave(String query) async {
    if (braveKey.trim().isEmpty) return _error('Brave key is not configured');
    final response = await _client
        .get(
          Uri.https('api.search.brave.com', '/res/v1/web/search', {
            'q': query,
            'count': '5',
          }),
          headers: {
            'X-Subscription-Token': braveKey,
            'Accept': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      return _error('Brave returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return _error('Invalid Brave response');
    }
    final web = decoded['web'];
    if (web is! Map<String, dynamic> || web['results'] is! List) {
      return _error('Invalid Brave response');
    }
    return _results(
      (web['results'] as List).whereType<Map<String, dynamic>>().map(
        (r) => {'title': r['title'], 'url': r['url'], 'text': r['description']},
      ),
    );
  }

  Future<String> _tavily(String query) async {
    if (tavilyKey.trim().isEmpty) return _error('Tavily key is not configured');
    final response = await _client
        .post(
          Uri.https('api.tavily.com', '/search'),
          headers: {
            'Authorization': 'Bearer $tavilyKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'query': query,
            'max_results': 5,
            'search_depth': 'basic',
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      return _error('Tavily returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['results'] is! List) {
      return _error('Invalid Tavily response');
    }
    return _results(
      (decoded['results'] as List).whereType<Map<String, dynamic>>().map(
        (r) => {'title': r['title'], 'url': r['url'], 'text': r['content']},
      ),
    );
  }

  String _results(Iterable<Map<String, dynamic>> results) => jsonEncode(
    results.take(5).map((r) {
      final url = r['url'];
      if (url is String && Uri.tryParse(url)?.scheme == 'https') {
        _foundUrls.add(url);
      }
      return {
        'title': _limit('${r['title'] ?? ''}', 250),
        'url': url,
        'text': _limit('${r['text'] ?? ''}', 1500),
      };
    }).toList(),
  );

  Future<String> _exa(String endpoint, Map<String, Object> body) async {
    if (exaKey.trim().isEmpty) return _error('Exa key is not configured');
    final response = await _client
        .post(
          Uri.https('api.exa.ai', endpoint),
          headers: {
            'Authorization': 'Bearer $exaKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      return _error('Exa returned HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['results'] is! List) {
      return _error('Invalid Exa response');
    }
    final results = (decoded['results'] as List)
        .whereType<Map<String, dynamic>>()
        .take(5)
        .map((result) {
          final url = result['url'];
          if (url is String && Uri.tryParse(url)?.scheme == 'https') {
            _foundUrls.add(url);
          }
          return {
            'title': result['title'],
            'url': url,
            'publishedDate': result['publishedDate'],
            'highlights': result['highlights'] is List
                ? (result['highlights'] as List)
                      .take(3)
                      .map((e) => _limit('$e', 1200))
                      .toList()
                : null,
            'text': result['text'] is String
                ? _limit(result['text'] as String, 8000)
                : null,
          };
        })
        .toList();
    return jsonEncode(results);
  }

  static String _limit(String text, int length) =>
      text.length > length ? '${text.substring(0, length)}…' : text;
  static String _error(String message) => jsonEncode({'error': message});
  void dispose() {
    if (_ownsClient) _client.close();
  }
}
