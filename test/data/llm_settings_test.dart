import 'package:devmate/data/llm_settings.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

void main() {
  setUp(
    () => dotenv.loadFromString(
      envString: 'LLM_BASE_URL=https://env.example/v1\nLLM_MODEL=env-model\nLLM_API_KEY=env-key',
    ),
  );

  test(
    'secure values override env, including deliberately empty values',
    () async {
      final storage = MemorySecureStorage();
      final repo = LlmSettingsRepository(storage: storage);
      expect((await repo.load()).model, 'env-model');
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
    },
  );

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
}
