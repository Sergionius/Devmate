// Ручная e2e-проверка device-code входа в ChatGPT-подписку (Codex backend).
//
// Запуск: dart run tools/codex_device_login_smoke.dart
// Открой выведенную ссылку в браузере, введи код, подтверди вход —
// инструмент напечатает маскированные токены и проверит inference-запрос.
import 'dart:convert';
import 'dart:io';

import 'package:devmate/data/codex_auth.dart';
import 'package:http/http.dart' as http;

String _mask(String token) => token.length <= 14
    ? '…'
    : '${token.substring(0, 8)}…${token.substring(token.length - 4)}';

Future<void> main() async {
  final api = CodexDeviceAuthApi();
  stdout.writeln('Запрашиваю код подтверждения…');
  CodexTokens tokens;
  try {
    tokens = await runCodexDeviceLogin(
      api: api,
      onCode: (code) {
        stdout
          ..writeln('')
          ..writeln('1. Открой в браузере: ${code.verificationUri}')
          ..writeln('2. Введи код: ${code.userCode}')
          ..writeln('   (ожидание подтверждения, лимит 15 минут…)')
          ..writeln('');
      },
    );
  } on CodexAuthException catch (error) {
    stderr.writeln('Вход не удался [${error.kind.name}]: ${error.message}');
    exitCode = 1;
    return;
  }

  stdout
    ..writeln('Вход выполнен.')
    ..writeln('  accountId : ${tokens.accountId}')
    ..writeln('  access    : ${_mask(tokens.access)}')
    ..writeln('  refresh   : ${_mask(tokens.refresh)}')
    ..writeln('  expiresAt : ${tokens.expiresAt.toIso8601String()}');

  // Мини-inference тем же путём, что и приложение:
  // POST {base}/codex/responses, store:false + stream:true.
  final response = await http.post(
    Uri.parse('https://chatgpt.com/backend-api/codex/responses'),
    headers: <String, String>{
      'Authorization': 'Bearer ${tokens.access}',
      'chatgpt-account-id': tokens.accountId,
      'originator': codexOriginator,
      'OpenAI-Beta': 'responses=experimental',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
    },
    body: jsonEncode(<String, dynamic>{
      'model': 'gpt-6-luna',
      'instructions': 'Отвечай одним словом.',
      'input': [
        {
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': 'Скажи ок'},
          ],
        },
      ],
      'store': false,
      'stream': true,
    }),
  );
  if (response.statusCode != 200) {
    stderr.writeln(
      'Inference не удался (HTTP ${response.statusCode}): '
      '${response.body.substring(0, response.body.length.clamp(0, 400))}',
    );
    exitCode = 1;
    return;
  }
  final delta = response.body
      .split('\n')
      .where(
        (line) =>
            line.startsWith('data: ') && line.contains('output_text.delta'),
      )
      .map((line) => jsonDecode(line.substring(6)) as Map<String, dynamic>)
      .map((event) => event['delta'])
      .whereType<String>()
      .join();
  stdout.writeln("Ответ модели: ${delta.isEmpty ? '(пусто!)' : delta}");
  stdout.writeln(delta.isEmpty ? 'E2E: FAIL' : 'E2E: OK');
  if (delta.isEmpty) exitCode = 1;
}
