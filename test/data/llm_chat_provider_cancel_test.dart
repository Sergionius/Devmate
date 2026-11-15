import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/data/llm_settings.dart';
import 'package:flutter_test/flutter_test.dart';

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
        } finally {
          handled.complete();
        }
      });
      return server;
    });

void main() {
  test(
    'dispose mid-stream tears down the connection and completes the consumer',
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
          .sendMessageStream('Question')
          .listen(
            (chunk) {
              chunks.add(chunk);
              if (!firstChunk.isCompleted) firstChunk.complete();
            },
            onDone: streamDone.complete,
            onError: streamDone.completeError,
            cancelOnError: true,
          );

      await firstChunk.future.timeout(const Duration(seconds: 2));
      expect(provider.history.last.text, isNotEmpty);

      provider.dispose();

      await streamDone.future.timeout(const Duration(seconds: 2));

      expect(chunks.length, lessThan(50));

      expect(provider.history.last.failed, isFalse);
      expect(provider.history.last.errorKind, isNull);

      await handled.future.timeout(const Duration(seconds: 2));
      await server.close(force: true);
    },
  );

  test('consumer cancel does not mark the answer failed and keeps a new stream working', () async {
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

    final firstChunk = Completer<void>();
    final sub = provider.sendMessageStream('Question').listen((chunk) {
      if (!firstChunk.isCompleted) firstChunk.complete();
    });
    await firstChunk.future.timeout(const Duration(seconds: 2));
    await sub.cancel();
    await handled.future.timeout(const Duration(seconds: 2));

    expect(provider.history.last.failed, isFalse);
    expect(provider.history.last.errorKind, isNull);

    final secondDone = Completer<void>();
    final secondChunks = <String>[];
    provider
        .sendMessageStream('Question 2')
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
  });
}
