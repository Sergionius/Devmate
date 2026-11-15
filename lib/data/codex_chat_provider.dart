import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openai_dart/openai_dart.dart' as oai;

import 'codex_auth.dart';
import 'codex_token_store.dart';
import 'llm_chat_provider.dart';
import 'llm_settings.dart';

LlmErrorKind classifyCodexError(Object error) {
  if (error is CodexAuthException) {
    return switch (error.kind) {
      CodexAuthErrorKind.sessionExpired => LlmErrorKind.subscriptionExpired,
      _ => LlmErrorKind.connection,
    };
  }

  if (error is oai.ApiException) {
    return switch (error.statusCode) {
      401 => LlmErrorKind.subscriptionExpired,
      404 => LlmErrorKind.notFound,
      429 => LlmErrorKind.rateLimited,
      _ => LlmErrorKind.connection,
    };
  }
  final text = error.toString();
  if (text.contains('401') || text.toLowerCase().contains('unauthorized')) {
    return LlmErrorKind.subscriptionExpired;
  }
  if (text.contains('404')) {
    return LlmErrorKind.notFound;
  }
  if (text.contains('429')) {
    return LlmErrorKind.rateLimited;
  }
  return kIsWeb ? LlmErrorKind.webConnection : LlmErrorKind.connection;
}

Future<LlmErrorKind?> testCodexConnection(
  LlmSettings settings, {
  CodexAuth? codexAuth,
}) async {
  try {
    final tokens = await (codexAuth ?? CodexAuth.shared).ensureFreshTokens();
    final client = _clientFor(settings.baseUrl.trim(), tokens);
    final stream = client.responses.createStream(
      buildCodexRequest(
        model: settings.model.trim(),
        systemPrompt: '',
        history: const [],
        prompt: llmTestPrompt,
      ),
    );
    await for (final event in stream) {
      if (event is oai.OutputTextDeltaEvent && event.delta.isNotEmpty) {
        return null;
      }
    }
    return LlmErrorKind.emptyTestResponse;
  } catch (error) {
    return classifyCodexError(error);
  }
}

oai.CreateResponseRequest buildCodexRequest({
  required String model,
  required String systemPrompt,
  required Iterable<LlmChatMessage> history,
  required String prompt,
}) {
  final trimmedSystemPrompt = systemPrompt.trim();
  return oai.CreateResponseRequest(
    model: model,
    input: oai.ResponseInput.items([
      for (final message in history)
        if (!message.failed && message.text.isNotEmpty)
          message.role == LlmRole.user
              ? oai.MessageItem.userText(message.text)
              : oai.MessageItem.assistantText(message.text),
      oai.MessageItem.userText(prompt),
    ]),
    instructions: trimmedSystemPrompt.isEmpty ? null : trimmedSystemPrompt,
    store: false,
    stream: true,
  );
}

oai.OpenAIClient _clientFor(String baseUrl, CodexTokens tokens) =>
    oai.OpenAIClient(
      config: oai.OpenAIConfig(
        authProvider: oai.ApiKeyProvider(tokens.access),
        baseUrl: baseUrl,
        defaultHeaders: <String, String>{
          'chatgpt-account-id': tokens.accountId,
          'originator': codexOriginator,
          'OpenAI-Beta': 'responses=experimental',
        },
      ),
    );

class CodexChatProvider extends ChangeNotifier implements ChatSession {
  CodexChatProvider({
    required LlmSettings settings,
    required this._codexAuth,
    required this._systemPrompt,
    oai.OpenAIClient Function(CodexTokens tokens)? clientFactory,
  }) : _settings = settings,
       _clientFactory =
           clientFactory ??
           ((tokens) => _clientFor(settings.baseUrl.trim(), tokens));

  final LlmSettings _settings;
  final CodexAuth _codexAuth;
  final String _systemPrompt;
  final oai.OpenAIClient Function(CodexTokens tokens) _clientFactory;
  final List<LlmChatMessage> _history = [];

  bool _active = true;
  Completer<void>? _abort;
  StreamController<String>? _controller;

  @override
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  @override
  Stream<String> sendMessageStream(String prompt) {
    assert(_controller == null, 'Одновременные стримы не поддерживаются');
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
          ..errorKind = classifyCodexError(error)
          ..errorDetail = llmErrorDetail(error);
        notifyListeners();
      }
      closeBridge();
    }

    controller = StreamController<String>(
      onListen: () {
        if (!_active) return;
        assistant = LlmChatMessage(LlmRole.assistant, '');
        _history
          ..add(LlmChatMessage(LlmRole.user, prompt))
          ..add(assistant);
        if (_active) notifyListeners();
        unawaited(
          Future<void>(() async {
            try {
              final tokens = await _codexAuth.ensureFreshTokens();
              if (!_active) return;
              final stream = _clientFactory(tokens).responses.createStream(
                buildCodexRequest(
                  model: _settings.model.trim(),
                  systemPrompt: _systemPrompt,

                  history: _history.sublist(0, _history.length - 2),
                  prompt: prompt,
                ),

                abortTrigger: abort.future,
              );
              stream.listen(
                (event) {
                  if (!_active) return;
                  switch (event) {
                    case oai.OutputTextDeltaEvent(:final delta):
                      if (delta.isEmpty) return;
                      received = true;
                      assistant.text += delta;
                      notifyListeners();
                      controller.add(delta);
                    case oai.ResponseFailedEvent():
                      fail(
                        const CodexAuthException(
                          CodexAuthErrorKind.rejected,
                          'Модель завершила поток с ошибкой (response.failed)',
                        ),
                      );
                    default:
                      break;
                  }
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
          }),
        );
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
