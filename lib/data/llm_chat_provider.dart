import 'dart:async';

import 'package:flutter/foundation.dart';
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

enum LlmRole { user, assistant }

/// One transcript entry shown in the chat and fed back as context.
class LlmChatMessage {
  LlmChatMessage(this.role, this.text, {this.failed = false});

  final LlmRole role;

  /// Failed replies are shown but never resent as conversation context.
  bool failed;
  String text;
}

List<oai.ChatMessage> _requestMessages(
  String systemPrompt,
  List<LlmChatMessage> history,
  String prompt,
) => [
  oai.ChatMessage.system(systemPrompt),
  for (final message in history)
    if (!message.failed && message.text.isNotEmpty)
      message.role == LlmRole.user
          ? oai.ChatMessage.user(message.text)
          : oai.ChatMessage.assistant(content: message.text),
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
  final lower = text.toLowerCase();
  if (lower.contains('insufficient balance') ||
      lower.contains('no resource package') ||
      lower.contains('billing')) {
    return 'На аккаунте провайдера нет средств или тарифного пакета. '
        'Пополните баланс или выберите другого провайдера.';
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

/// Talks to any OpenAI-compatible endpoint (z.ai, OpenRouter, DeepSeek, Groq,
/// Ollama, OpenAI, ...) with streaming. Keeps one conversation in memory:
/// [history] is the transcript, failed replies are kept visible for the user
/// but excluded from follow-up requests.
class OpenAiCompatibleProvider extends ChangeNotifier {
  OpenAiCompatibleProvider({
    required this._settings,
    required this._systemPrompt,
  });

  final LlmSettings _settings;
  final String _systemPrompt;
  final List<LlmChatMessage> _history = [];

  /// Transcript of the conversation, oldest first.
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  /// Streams the assistant reply to [prompt], appending both turns to
  /// [history]. Yields text chunks as they arrive.
  Stream<String> sendMessageStream(String prompt) async* {
    final assistant = LlmChatMessage(LlmRole.assistant, '');
    _history
      ..add(LlmChatMessage(LlmRole.user, prompt))
      ..add(assistant);
    notifyListeners();

    try {
      final client = _clientFor(_settings);
      final stream = client.chat.completions.createStream(
        oai.ChatCompletionCreateRequest(
          model: _settings.model.trim(),
          temperature: 0.6,
          messages: _requestMessages(
            _systemPrompt,
            _history.sublist(0, _history.length - 1),
            prompt,
          ),
        ),
      );
      var received = false;
      await for (final event in stream) {
        final delta = event.textDelta;
        if (delta != null && delta.isNotEmpty) {
          received = true;
          assistant.text += delta;
          notifyListeners();
          yield delta;
        }
      }
      if (!received) {
        assistant.text = 'Провайдер вернул пустой ответ.';
        notifyListeners();
        yield assistant.text;
      }
    } catch (error) {
      assistant
        ..failed = true
        ..text +=
            (assistant.text.isEmpty ? '' : '\n\n') + describeLlmError(error);
      notifyListeners();
      yield assistant.text;
    } finally {
      notifyListeners();
    }
  }
}
