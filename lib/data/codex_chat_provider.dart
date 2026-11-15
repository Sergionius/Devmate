import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openai_dart/openai_dart.dart' as oai;

import 'codex_auth.dart';
import 'codex_token_store.dart';
import 'llm_chat_provider.dart';
import 'llm_settings.dart';

/// Маппинг ошибок Codex-подписки в [LlmErrorKind]. Отличия от ключей API:
/// 401 и мёртвый refresh-токен — это «сессия истекла, войдите заново»,
/// а не «ключ отклонён».
LlmErrorKind classifyCodexError(Object error) {
  if (error is CodexAuthException) {
    return switch (error.kind) {
      CodexAuthErrorKind.sessionExpired => LlmErrorKind.subscriptionExpired,
      _ => LlmErrorKind.connection,
    };
  }
  // Типизированная ветка надёжнее матчинга по toString().
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

/// Тестовое соединение с Codex backend: маленький стрим-запрос тем же путём,
/// что и настоящий чат (превью-ограничения OpenAI требуют store:false +
/// stream:true на каждый HTTP-запрос). Нет токенов — [LlmErrorKind.subscriptionExpired].
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

/// Тело запроса Responses API для Codex backend. Чистая функция — покрытие
/// маппинга истории в тестах без сети.
///
/// Ограничения превью-потока ChatGPT plan usage (для device-флоу backend
/// ожидает тот же формат): system-сообщения запрещены — системный промпт
/// идёт в `instructions`; история — в `input`; store:false, stream:true.
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
        // Access-токен OAuth идёт как обычный Bearer.
        authProvider: oai.ApiKeyProvider(tokens.access),
        baseUrl: baseUrl,
        defaultHeaders: <String, String>{
          'chatgpt-account-id': tokens.accountId,
          'originator': codexOriginator,
          'OpenAI-Beta': 'responses=experimental',
        },
      ),
    );

/// Сессия чата с ChatGPT-подпиской (Codex backend, Responses API).
/// Контракты [ChatSession] и отмены — те же, что у [OpenAiCompatibleProvider]:
/// dispose() рвёт активный HTTP-стрим, notify после dispose запрещены,
/// одновременные стримы не поддерживаются.
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

  /// false после [dispose]: генерация останавливается, notify запрещены.
  bool _active = true;
  Completer<void>? _abort;
  StreamController<String>? _controller;

  /// Transcript of the conversation, oldest first.
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
        if (!_active) return; // dispose успел раньше подписки
        assistant = LlmChatMessage(LlmRole.assistant, '');
        _history
          ..add(LlmChatMessage(LlmRole.user, prompt))
          ..add(assistant);
        if (_active) notifyListeners();
        unawaited(
          Future<void>(() async {
            try {
              // Свежие токены до запроса; параллельные стримы невозможны по
              // контракту, поэтому single-flight refresh здесь достаточен.
              final tokens = await _codexAuth.ensureFreshTokens();
              if (!_active) return; // dispose во время refresh
              final stream = _clientFactory(tokens).responses.createStream(
                buildCodexRequest(
                  model: _settings.model.trim(),
                  systemPrompt: _systemPrompt,
                  // Исключаем только что добавленную пару (user, assistant):
                  // новый prompt buildCodexRequest добавит сам, иначе — дубль.
                  history: _history.sublist(0, _history.length - 2),
                  prompt: prompt,
                ),
                // Транспортная отмена средствами openai_dart: abort.future
                // рвёт HTTP-запрос изнутри библиотеки.
                abortTrigger: abort.future,
              );
              stream.listen(
                (event) {
                  if (!_active) return; // dispose(): тихо докатываемся
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
      // Потребитель отменил поток — рвём и транспорт.
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

  /// Немедленная отмена: abortTrigger рвёт HTTP-запрос на транспортном
  /// уровне, закрытие моста отдаёт потребителю done, а не зависание.
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
