import 'dart:convert';

/// Собирает фейковый JWT с нужным chatgpt_account_id в payload.
String fakeJwt(String accountId) {
  String segment(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final header = segment(<String, String>{'alg': 'RS256'});
  final payload = segment(<String, dynamic>{
    'https://api.openai.com/auth': <String, String>{
      'chatgpt_account_id': accountId,
    },
  });
  return '$header.$payload.c2ln';
}
