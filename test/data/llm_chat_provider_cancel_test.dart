import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:flutter_test/flutter_test.dart';

// Без TestWidgetsFlutterBinding: он перехватывает HTTP (все запросы → 400),
// а тест отмены поднимает реальный локальный SSE-сервер.

String _chunkJson(String text) => jsonEncode({
  'id': 'chatcmpl-test',
  'object': 'chat.completion.chunk',
  'created': 1700000000,
  'model': 'test-model',
  'choices': [
    {
      'index': 0,
      'delta': {'content': text},
      'finish_reason': null,
    },
  ],
});

/// Медленный SSE-сервер: 50 чанков по 30мс (~1.5с на полный ответ).
Future<HttpServer> _startSlowServer(Completer<void> handled) =>
    HttpServer.bind(InternetAddress.loopbackIPv4, 0).then((server) {
      server.listen((request) async {
        try {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf8',
          );
          for (var i = 0; i < 50; i++) {
            request.response.write('data: ${_chunkJson('chunk $i')}\n\n');
            await request.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 30));
          }
          await request.response.close();
        } catch (_) {
          // Клиент оборвал соединение после dispose — это и есть цель.
        } finally {
          handled.complete();
        }
      });
      return server;
    });

void main() {
  test(
    'dispose посреди стрима рвёт соединение и завершает потребитель',
    () async {
      final handled = Completer<void>();
      final server = await _startSlowServer(handled);

      final provider = OpenAiCompatibleProvider(
        settings: LlmSettings(
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          model: 'test-model',
          apiKey: 'k',
        ),
        systemPrompt: '',
      );
      final chunks = <String>[];
      final firstChunk = Completer<void>();
      final streamDone = Completer<void>();
      provider
          .sendMessageStream('Вопрос')
          .listen(
            (chunk) {
              chunks.add(chunk);
              if (!firstChunk.isCompleted) firstChunk.complete();
            },
            onDone: streamDone.complete,
            onError: streamDone.completeError,
            cancelOnError: true,
          );
      // Ждём первый чанк: данные реально пошли по соединению.
      await firstChunk.future.timeout(const Duration(seconds: 2));
      expect(provider.history.last.text, isNotEmpty);

      provider.dispose();
      // Отмена закрывает поток promptly — потребитель не висит до конца
      // серверной генерации (~1.5с осталось бы без отмены).
      await streamDone.future.timeout(const Duration(seconds: 2));
      // Стрим оборван: не все 50 кусков дошли до потребителя.
      expect(chunks.length, lessThan(50));
      // Оборванный ответ не помечается ошибкой — это отмена, не сбой.
      expect(provider.history.last.failed, isFalse);
      expect(provider.history.last.errorKind, isNull);

      await handled.future.timeout(const Duration(seconds: 2));
      await server.close(force: true);
    },
  );

  test(
    'cancel потребителя не помечает ответ failed и не ломает новый стрим',
    () async {
      final handled = Completer<void>();
      final server = await _startSlowServer(handled);

      final provider = OpenAiCompatibleProvider(
        settings: LlmSettings(
          baseUrl: 'http://127.0.0.1:${server.port}/v1',
          model: 'test-model',
          apiKey: 'k',
        ),
        systemPrompt: '',
      );

      // Первый стрим: потребитель сам отменяет подписку посреди ответа.
      final firstChunk = Completer<void>();
      final sub = provider.sendMessageStream('Вопрос').listen((chunk) {
        if (!firstChunk.isCompleted) firstChunk.complete();
      });
      await firstChunk.future.timeout(const Duration(seconds: 2));
      await sub.cancel();
      await handled.future.timeout(const Duration(seconds: 2));
      // Отмена потребителя — не сбой: abort не помечает ответ (контракт).
      expect(provider.history.last.failed, isFalse);
      expect(provider.history.last.errorKind, isNull);

      // Отложенные колбэки старого стрима не должны затереть регистрацию
      // нового: второй стрим обязан корректно отменяться dispose-ом.
      final secondDone = Completer<void>();
      final secondChunks = <String>[];
      provider
          .sendMessageStream('Вопрос 2')
          .listen(
            secondChunks.add,
            onDone: secondDone.complete,
            onError: secondDone.completeError,
            cancelOnError: true,
          );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      provider.dispose();
      await secondDone.future.timeout(const Duration(seconds: 2));
      expect(secondChunks.length, lessThan(50));

      await server.close(force: true);
    },
  );
}
