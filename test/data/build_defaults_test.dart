import 'package:devmate/data/llm_settings.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

void main() {
  test(
    'build defines reach settings, but saved values take precedence',
    () async {
      const baseUrl = String.fromEnvironment('LLM_BASE_URL');
      const model = String.fromEnvironment('LLM_MODEL');
      const key = String.fromEnvironment('LLM_API_KEY');
      final defaults = LlmSettingsRepository.buildDefaults;
      expect(defaults.baseUrl, baseUrl);
      expect(defaults.model, model);
      expect(defaults.apiKey, key);

      final repo = LlmSettingsRepository(storage: MemorySecureStorage());
      expect((await repo.load()).apiKey, defaults.apiKey);
      await repo.save(const LlmSettings(baseUrl: '', model: '', apiKey: ''));
      expect((await repo.load()).apiKey, isEmpty);
      await repo.clear();
      expect((await repo.load()).apiKey, isEmpty);
    },
  );
}
