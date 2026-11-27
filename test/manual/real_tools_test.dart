import 'dart:io';

import 'package:devmate/data/chat_tools.dart';
import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/domain/question.dart';
import 'package:flutter_test/flutter_test.dart';

class _ObservedTools extends ChatTools {
  _ObservedTools(TopicCatalog catalog) : super(catalog: catalog, exaKey: '');
  bool wasCalled = false;
  @override
  Future<String> execute(String name, String rawArguments) {
    wasCalled = true;
    return super.execute(name, rawArguments);
  }
}

// Run explicitly with: flutter test test/manual/real_tools_test.dart
//   --dart-define-from-file=config/local.json
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => HttpOverrides.global = null);

  test('configured LLM can call a local catalog tool', () async {
    final settings = LlmSettingsRepository.buildDefaults;
    if (!settings.isConfigured) {
      markTestSkipped('LLM key/model not configured');
      return;
    }
    final catalog = TopicCatalog(
      baseTopics: [
        const InterviewTopic('tool-test-topic', 'Dart', '', [
          InterviewQuestion(
            'tool-test-question',
            'What is an isolate?',
            'It has a separate memory heap.',
          ),
        ]),
      ],
    );
    final tools = _ObservedTools(catalog);
    final provider = OpenAiCompatibleProvider(
      settings: settings,
      systemPrompt: 'You must call find_questions before answering. Reply with the exact question returned by the tool.',
      tools: tools,
    );
    addTearDown(provider.dispose);
    final answer = await provider
        .sendMessageStream('Find the isolate question in my catalog.')
        .join();
    expect(
      provider.history.last.failed,
      isFalse,
      reason: 'The configured model must support OpenAI-style tool calls',
    );
    expect(
      tools.wasCalled,
      isTrue,
      reason: 'The model must actually invoke a tool',
    );
    expect(answer.toLowerCase(), contains('isolate'));
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('configured Exa key searches the web', () async {
    const key = String.fromEnvironment('EXA_API_KEY');
    if (key.isEmpty) {
      markTestSkipped('Exa key not configured');
      return;
    }
    final tools = ChatTools(exaKey: key);
    addTearDown(tools.dispose);
    final response = await tools.execute(
      'search_web',
      '{"query":"Flutter official docs"}',
    );
    expect(response, contains('https://'));
  }, timeout: const Timeout(Duration(minutes: 1)));
}
