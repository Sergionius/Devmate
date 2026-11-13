import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:openai_dart/openai_dart.dart' as oai;

import 'llm_settings.dart';

class LlmConnectionException implements Exception {
  LlmConnectionException(this.message);
  final String message;

  @override
  String toString() => message;
}

oai.OpenAIClient _clientFor(LlmSettings settings) => oai.OpenAIClient(
  config: oai.OpenAIConfig(
    authProvider: oai.ApiKeyProvider(settings.apiKey.trim()),
    baseUrl: settings.baseUrl.trim(),
  ),
);

List<oai.ChatMessage> _requestMessages(
  String systemPrompt,
  List<String> pastUser,
  List<String> pastAssistant,
  String prompt,
) => [
  oai.ChatMessage.system(systemPrompt),
  for (var i = 0; i < pastUser.length; i++) ...[
    oai.ChatMessage.user(pastUser[i]),
    oai.ChatMessage.assistant(content: pastAssistant[i]),
  ],
  oai.ChatMessage.user(prompt),
];

/// Maps low-level client errors to messages a user can act on.
String describeLlmError(Object error) {
  final text = error.toString();
  if (text.contains('401') || text.toLowerCase().contains('unauthorized')) {
    return 'Ключ отклонён (401). Проверьте API-ключ в настройках.';
  }
  if (text.contains('404')) {
    return 'Адрес или модель не найдены (404). Проверьте base URL и название модели.';
  }
  if (text.contains('429')) {
    return 'Слишком много запросов (429). Подождите или проверьте квоту.';
  }
  return kIsWeb
      ? 'Ошибка соединения с провайдером. На web работают только провайдеры с CORS '
            '(OpenAI, OpenRouter, Groq). Проверьте настройки и интернет.'
      : 'Ошибка соединения с провайдером. Проверьте настройки и интернет.';
}

/// Sends a tiny request to verify that key, URL and model work together.
Future<String?> testLlmConnection(LlmSettings settings) async {
  try {
    final client = _clientFor(settings);
    final response = await client.chat.completions.create(
      oai.ChatCompletionCreateRequest(
        model: settings.model.trim(),
        maxTokens: 5,
        messages: [oai.ChatMessage.user('Ответь одним словом: ок')],
      ),
    );
    if (response.text == null || response.text!.isEmpty) {
      return 'Провайдер ответил пустым сообщением.';
    }
    return null;
  } catch (error) {
    return describeLlmError(error);
  }
}

/// [LlmProvider] for any OpenAI-compatible endpoint (z.ai, OpenRouter,
/// DeepSeek, Groq, Ollama, OpenAI, ...). Keeps the conversation history
/// in memory for one chat session.
class OpenAiCompatibleProvider extends LlmProvider with ChangeNotifier {
  OpenAiCompatibleProvider({
    required this._settings,
    required this._systemPrompt,
  });

  final LlmSettings _settings;
  final String _systemPrompt;
  final List<ChatMessage> _history = [];
  final Set<ChatMessage> _failedMessages = {};

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> history) {
    _history
      ..clear()
      ..addAll(history);
    _failedMessages.removeWhere((message) => !_history.contains(message));
    notifyListeners();
  }

  (List<String>, List<String>) get _pastTurns {
    final users = <String>[];
    final assistants = <String>[];
    for (var i = 0; i + 1 < _history.length; i += 2) {
      final user = _history[i];
      final assistant = _history[i + 1];
      if (user.origin != MessageOrigin.user ||
          assistant.origin != MessageOrigin.llm ||
          _failedMessages.contains(assistant) ||
          (assistant.text ?? '').isEmpty) {
        continue;
      }
      users.add(user.text ?? '');
      assistants.add(assistant.text!);
    }
    return (users, assistants);
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final userMessage = ChatMessage.user(prompt, const []);
    final llmMessage = ChatMessage.llm();
    _history.addAll([userMessage, llmMessage]);
    notifyListeners();

    try {
      final (pastUsers, pastAssistants) = _pastTurns;
      final messages = _requestMessages(
        _systemPrompt,
        pastUsers,
        pastAssistants,
        prompt,
      );
      final stream = _clientFor(_settings).chat.completions.createStream(
        oai.ChatCompletionCreateRequest(
          model: _settings.model.trim(),
          temperature: 0.6,
          messages: messages,
        ),
      );
      var received = false;
      await for (final event in stream) {
        final delta = event.textDelta;
        if (delta != null && delta.isNotEmpty) {
          received = true;
          llmMessage.append(delta);
          yield delta;
        }
      }
      if (!received) {
        const empty = 'Провайдер вернул пустой ответ.';
        llmMessage.append(empty);
        yield empty;
      }
    } catch (error) {
      _failedMessages.add(llmMessage);
      final message = describeLlmError(error);
      llmMessage.append('\n\n$message');
      yield '\n\n$message';
    } finally {
      notifyListeners();
    }
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    final stream = _clientFor(_settings).chat.completions.createStream(
      oai.ChatCompletionCreateRequest(
        model: _settings.model.trim(),
        temperature: 0.6,
        messages: _requestMessages(_systemPrompt, const [], const [], prompt),
      ),
    );
    await for (final event in stream) {
      final delta = event.textDelta;
      if (delta != null && delta.isNotEmpty) yield delta;
    }
  }
}
