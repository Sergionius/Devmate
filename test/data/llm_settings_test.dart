import 'package:devmate/data/llm_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

void main() {
  test('settings start empty and preserve deliberately empty values', () async {
    final storage = MemorySecureStorage();
    final repo = LlmSettingsRepository(storage: storage);
    expect((await repo.load()).model, isEmpty);
    await repo.save(
      const LlmSettings(
        baseUrl: 'https://new.example/v1',
        model: 'new-model',
        apiKey: '',
      ),
    );
    final loaded = await repo.load();
    expect(loaded.baseUrl, 'https://new.example/v1');
    expect(loaded.model, 'new-model');
    expect(loaded.apiKey, isEmpty);
  });

  test('preset detection uses the endpoint URL', () {
    final repo = LlmSettingsRepository(storage: MemorySecureStorage());
    expect(
      repo
          .detectPreset(
            const LlmSettings(
              baseUrl: 'https://api.z.ai/api/coding/paas/v4',
              model: 'glm-5.3-flash',
              apiKey: '',
            ),
          )
          ?.id,
      'zaiCoding',
    );
    expect(
      repo
          .detectPreset(
            const LlmSettings(
              baseUrl: 'https://api.z.ai/api/paas/v4',
              model: 'anything',
              apiKey: '',
            ),
          )
          ?.id,
      'zai',
    );
    expect(
      repo
          .detectPreset(
            const LlmSettings(
              baseUrl: 'https://example.com/v1',
              model: 'x',
              apiKey: '',
            ),
          )
          ?.id,
      'custom',
    );
  });

  test('legacy device-code settings and tokens are removed on load', () async {
    final storage = MemorySecureStorage()
      ..values['llm.authMode'] = 'codexDeviceCode'
      ..values['codex.auth'] = 'old-token'
      ..values['llm.baseUrl'] = 'https://chatgpt.com/backend-api/codex';
    final repo = LlmSettingsRepository(storage: storage);
    final loaded = await repo.load();
    expect(loaded.isConfigured, isFalse);
    expect(loaded.baseUrl, isEmpty);
    expect(storage.values['codex.auth'], isNull);
    expect(storage.values['llm.authMode'], isNull);
  });

  test('reset clears settings and legacy tokens', () async {
    final storage = MemorySecureStorage()..values['codex.auth'] = 'old-token';
    final repo = LlmSettingsRepository(storage: storage);
    await repo.clear();
    final loaded = await repo.load();
    expect(loaded.baseUrl, isEmpty);
    expect(loaded.model, isEmpty);
    expect(loaded.apiKey, isEmpty);
    expect(storage.values['codex.auth'], isNull);
  });

  test('API-key settings require a key', () {
    const settings = LlmSettings(
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4.1-mini',
      apiKey: '',
    );
    expect(settings.isConfigured, isFalse);
  });
}
