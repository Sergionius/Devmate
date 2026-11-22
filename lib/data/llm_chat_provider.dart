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

class LlmChatMessage {
  LlmChatMessage(this.role, this.text, {this.failed = false});

  final LlmRole role;

  bool failed;

  LlmErrorKind? errorKind;

  String? errorDetail;
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

enum LlmErrorKind {
  keyRejected,
  notFound,
  rateLimited,
  noBalance,
  webConnection,
  connection,
  emptyTestResponse,
  emptyReply,
}

const List<String> _quotaMarkers = [
  'insufficient balance',
  'no resource package',
  'billing',
  'subscription',
  'quota',
  'usage limit',
  'exceeded your',
  'package has expired',
];

LlmErrorKind? _kindFromText(String text) {
  final lower = text.toLowerCase();
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return LlmErrorKind.keyRejected;
  }
  if (lower.contains('404')) {
    return LlmErrorKind.notFound;
  }
  for (final marker in _quotaMarkers) {
    if (lower.contains(marker)) {
      return LlmErrorKind.noBalance;
    }
  }
  if (lower.contains('429')) {
    return LlmErrorKind.rateLimited;
  }
  if (lower.contains('403')) {
    return LlmErrorKind.keyRejected;
  }
  return null;
}

LlmErrorKind classifyLlmError(Object error) {
  if (error is oai.ApiException) {
    final fromText = _kindFromText(
      '${error.message} ${error.code} ${error.type}',
    );
    return switch (error.statusCode) {
      401 => LlmErrorKind.keyRejected,
      404 => LlmErrorKind.notFound,
      _ =>
        fromText ??
            switch (error.statusCode) {
              403 => LlmErrorKind.keyRejected,
              429 => LlmErrorKind.rateLimited,
              _ =>
                kIsWeb ? LlmErrorKind.webConnection : LlmErrorKind.connection,
            },
    };
  }
  final text = error.toString();
  return _kindFromText(text) ??
      (kIsWeb ? LlmErrorKind.webConnection : LlmErrorKind.connection);
}

String? llmErrorDetail(Object error) {
  if (error is oai.OpenAIException) {
    final message = error.message.trim();
    if (message.isEmpty) return null;
    return _truncate(message);
  }
  final text = error.toString().trim();
  if (text.isEmpty) return null;
  return _truncate(text);
}

String _truncate(String text) =>
    text.length > 300 ? '${text.substring(0, 300)}…' : text;

const String llmTestPrompt = 'Reply with one word: ok';

Future<LlmErrorKind?> testLlmConnection(LlmSettings settings) async {
  try {
    final client = _clientFor(settings);
    final response = await client.chat.completions.create(
      oai.ChatCompletionCreateRequest(
        model: settings.model.trim(),
        maxTokens: 5,
        messages: [oai.ChatMessage.user(llmTestPrompt)],
      ),
    );
    if (response.text == null || response.text!.isEmpty) {
      return LlmErrorKind.emptyTestResponse;
    }
    return null;
  } catch (error) {
    return classifyLlmError(error);
  }
}

abstract interface class ChatSession implements Listenable {
  List<LlmChatMessage> get history;

  Stream<String> sendMessageStream(String prompt, {bool retry = false});

  void dispose();
}

class OpenAiCompatibleProvider extends ChangeNotifier implements ChatSession {
  OpenAiCompatibleProvider({
    required this._settings,
    required this._systemPrompt,
  });

  final LlmSettings _settings;
  final String _systemPrompt;
  final List<LlmChatMessage> _history = [];

  bool _active = true;
  Completer<void>? _abort;
  StreamController<String>? _controller;

  @override
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  @override
  Stream<String> sendMessageStream(String prompt, {bool retry = false}) {
    assert(_controller == null, 'Concurrent streams are not supported');
    if (retry &&
        (_history.length < 2 ||
            _history[_history.length - 2].role != LlmRole.user ||
            _history[_history.length - 2].text != prompt ||
            _history.last.role != LlmRole.assistant ||
            !_history.last.failed)) {
      throw StateError('Only the last failed reply can be retried');
    }
    late final StreamController<String> controller;
    var received = false;
    late final LlmChatMessage assistant;
    final abort = Completer<void>();

    void closeBridge() {
      if (!controller.isClosed) unawaited(controller.close());
    }

    void fail(Object error) {
      if (identical(_abort, abort)) _abort = null;
      if (identical(_controller, controller)) _controller = null;

      if (_active && !abort.isCompleted) {
        assistant
          ..failed = true
          ..errorKind = classifyLlmError(error)
          ..errorDetail = llmErrorDetail(error);
        notifyListeners();
      }
      closeBridge();
    }

    controller = StreamController<String>(
      onListen: () {
        if (!_active) return;
        assistant = LlmChatMessage(LlmRole.assistant, '');
        if (retry) {
          _history.removeLast();
          _history.add(assistant);
        } else {
          _history
            ..add(LlmChatMessage(LlmRole.user, prompt))
            ..add(assistant);
        }
        if (_active) notifyListeners();
        try {
          final client = _clientFor(_settings);
          final stream = client.chat.completions.createStream(
            oai.ChatCompletionCreateRequest(
              model: _settings.model.trim(),
              temperature: 0.6,
              messages: _requestMessages(
                _systemPrompt,

                _history.sublist(0, _history.length - 2),
                prompt,
              ),
            ),

            abortTrigger: abort.future,
          );
          stream.listen(
            (event) {
              if (!_active) return;
              final delta = event.textDelta;
              if (delta == null || delta.isEmpty) return;
              received = true;
              assistant.text += delta;
              notifyListeners();
              controller.add(delta);
            },
            onError: fail,
            onDone: () {
              if (identical(_abort, abort)) _abort = null;
              if (identical(_controller, controller)) _controller = null;
              if (_active) {
                if (!received) {
                  assistant
                    ..failed = true
                    ..errorKind = LlmErrorKind.emptyReply;
                }
                notifyListeners();
              }
              closeBridge();
            },
          );
        } catch (error) {
          fail(error);
        }
      },

      onCancel: () {
        if (!abort.isCompleted) abort.complete();
        _abort = null;
        _controller = null;
      },
    );
    _abort = abort;
    _controller = controller;
    return controller.stream;
  }

  @override
  void dispose() {
    _active = false;

    if (!(_abort?.isCompleted ?? true)) _abort?.complete();
    _abort = null;
    final controller = _controller;
    _controller = null;
    if (controller != null && !controller.isClosed) {
      unawaited(controller.close());
    }
    super.dispose();
  }
}
