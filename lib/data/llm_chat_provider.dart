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

  /// Why the reply failed; localized in UI via context.llmErrorText.
  LlmErrorKind? errorKind;

  /// Raw provider message for [errorKind]; UI-only, never sent back to the
  /// provider. Null when the failure has no meaningful provider text.
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

/// Вид ошибки LLM-провайдера. Локализуется в UI (context.llmErrorText).
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

/// Речевые маркеры лимитов подписки/квоты у OpenAI-совместимых провайдеров
/// (z.ai, OpenRouter и т.п.): приходим к [LlmErrorKind.noBalance], чтобы
/// пользователь понял, что дело не в сети. Маркеры сознательно узкие —
/// применяются только к текстам ошибок; порядок: до 429, потому что лимит
/// плана (например, у z.ai) часто приходит как 429/403 с этими словами,
/// и пользователю полезнее подсказка про подписку, чем про rate limit.
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

/// Maps low-level client errors to [LlmErrorKind].
LlmErrorKind classifyLlmError(Object error) {
  // Типизированные ошибки openai_dart классифицируем по HTTP-коду и
  // содержимому ответа — toString() содержит requestId/код и ненадёжен.
  if (error is oai.ApiException) {
    final fromText = _kindFromText('${error.message} ${error.code} ${error.type}');
    return switch (error.statusCode) {
      401 => LlmErrorKind.keyRejected,
      404 => LlmErrorKind.notFound,
      _ =>
        fromText ??
        switch (error.statusCode) {
          403 => LlmErrorKind.keyRejected,
          429 => LlmErrorKind.rateLimited,
          _ => kIsWeb
              ? LlmErrorKind.webConnection
              : LlmErrorKind.connection,
        },
    };
  }
  final text = error.toString();
  return _kindFromText(text) ??
      (kIsWeb ? LlmErrorKind.webConnection : LlmErrorKind.connection);
}

/// Сырое сообщение провайдера для показа в чате; null — показывать нечего.
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

String _truncate(String text) => text.length > 300
    ? '${text.substring(0, 300)}…'
    : text;

/// Тестовая инструкция модели — не UI-текст, локализуется на уровне модели.
const String llmTestPrompt = 'Ответь одним словом: ок';

/// Sends a tiny request to verify that key, URL and model work together.
/// Returns null on success or the failure kind to localize in UI.
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

/// Сессия одного чата: история диалога + потоковые ответы. Абстракция над
/// [OpenAiCompatibleProvider] — ChatViewModel и экран слушают её напрямую
/// (гранулярный ребилд), в тестах подменяется фейком.
/// Контракт отмены: `dispose()` рвёт активный HTTP-стрим (abortTrigger) —
/// потребитель получает done, соединение закрывается, notify после dispose
/// не будет.
abstract interface class ChatSession implements Listenable {
  /// Transcript of the conversation, oldest first.
  List<LlmChatMessage> get history;

  /// Streams the assistant reply to [prompt], appending both turns to
  /// [history]. Yields text chunks as they arrive.
  Stream<String> sendMessageStream(String prompt);

  void dispose();
}

/// Talks to any OpenAI-compatible endpoint (z.ai, OpenRouter, DeepSeek, Groq,
/// Ollama, OpenAI, ...) with streaming. Keeps one conversation in memory:
/// [history] is the transcript, failed replies are kept visible for the user
/// but excluded from follow-up requests.
class OpenAiCompatibleProvider extends ChangeNotifier implements ChatSession {
  OpenAiCompatibleProvider({
    required this._settings,
    required this._systemPrompt,
  });

  final LlmSettings _settings;
  final String _systemPrompt;
  final List<LlmChatMessage> _history = [];

  /// false после [dispose]: генерация останавливается, notify запрещены.
  bool _active = true;
  Completer<void>? _abort;
  StreamController<String>? _controller;

  /// Transcript of the conversation, oldest first.
  @override
  List<LlmChatMessage> get history => List.unmodifiable(_history);

  /// Streams the assistant reply to [prompt], appending both turns to
  /// [history]. Yields text chunks as they arrive. Отмена активного
  /// ответа — через [dispose]: он рвёт HTTP-подписку немедленно,
  /// не дожидаясь следующего чанка.
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
      // Обнуляем поля только если они ещё указывают на ЭТОТ стрим:
      // отложенный колбэк старого стрима не должен затереть регистрацию
      // нового (иначе dispose() его не отменит — та самая утечка).
      if (identical(_abort, abort)) _abort = null;
      if (identical(_controller, controller)) _controller = null;
      // Отмену запросили мы (dispose/onCancel через abort) — это не сбой:
      // не помечаем ответ failed, контракт ChatSession.
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
        if (!_active) return; // dispose успел раньше подписки
        assistant = LlmChatMessage(LlmRole.assistant, '');
        _history
          ..add(LlmChatMessage(LlmRole.user, prompt))
          ..add(assistant);
        if (_active) notifyListeners();
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
            // Транспортная отмена средствами openai_dart: abort.future
            // рвёт HTTP-запрос изнутри библиотеки.
            abortTrigger: abort.future,
          );
          stream.listen(
            (event) {
              if (!_active) return; // dispose(): тишо докатываемся
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
      // Потребитель отменил поток — рвём и транспорт. Основной путь
      // отмены — dispose(), этот путь на будушее для подписчиков-UI.
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
  /// Ограничение (сознательное): одновременные стримы не поддерживаются;
  /// в release вместо assert это просто не определено, как и прежде.
  @override
  void dispose() {
    _active = false;
    // Немедленная отмена: abortTrigger рвёт HTTP-запрос на транспортном
    // уровне, закрытие моста отдаёт потребителю done, а не зависание.
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
