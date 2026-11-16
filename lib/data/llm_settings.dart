import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LlmSettings {
  const LlmSettings({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
  });

  final String baseUrl;
  final String model;
  final String apiKey;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty;

  LlmSettings copyWith({String? baseUrl, String? model, String? apiKey}) =>
      LlmSettings(
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
        apiKey: apiKey ?? this.apiKey,
      );

  Map<String, String> toMap() => {
    'baseUrl': baseUrl,
    'model': model,
    'apiKey': apiKey,
  };

  static LlmSettings fromMap(Map<String, String> map) => LlmSettings(
    baseUrl: map['baseUrl'] ?? '',
    model: map['model'] ?? '',
    apiKey: map['apiKey'] ?? '',
  );
}

class LlmPreset {
  const LlmPreset(
    this.id,
    this.label,
    this.baseUrl,
    this.defaultModel, {
    this.worksInBrowser = false,
  });
  final String id;
  final String label;
  final String baseUrl;
  final String defaultModel;

  final bool worksInBrowser;
}

const llmPresets = <LlmPreset>[
  LlmPreset(
    'zaiCoding',
    'z.ai GLM Coding (subscription)',
    'https://api.z.ai/api/coding/paas/v4',
    'glm-5.3-flash',
  ),
  LlmPreset(
    'zai',
    'z.ai API (pay-as-you-go)',
    'https://api.z.ai/api/paas/v4',
    'glm-5.3-flash',
  ),
  LlmPreset(
    'openai',
    'OpenAI',
    'https://api.openai.com/v1',
    'gpt-4.1-mini',
    worksInBrowser: true,
  ),
  LlmPreset(
    'openrouter',
    'OpenRouter',
    'https://openrouter.ai/api/v1',
    'openai/gpt-4o-mini',
    worksInBrowser: true,
  ),
  LlmPreset(
    'deepseek',
    'DeepSeek',
    'https://api.deepseek.com/v1',
    'deepseek-chat',
  ),
  LlmPreset(
    'groq',
    'Groq',
    'https://api.groq.com/openai/v1',
    'llama-3.3-70b-versatile',
    worksInBrowser: true,
  ),
  LlmPreset(
    'ollama',
    'Ollama (local)',
    'http://localhost:11434/v1',
    'llama3.1',
  ),
  LlmPreset('custom', 'Custom endpoint', '', ''),
];

LlmPreset? presetById(String id) {
  for (final preset in llmPresets) {
    if (preset.id == id) return preset;
  }
  return null;
}

class LlmSettingsRepository {
  LlmSettingsRepository({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _baseUrlKey = 'llm.baseUrl';
  static const _modelKey = 'llm.model';
  static const _apiKeyKey = 'llm.apiKey';
  static const _legacyAuthModeKey = 'llm.authMode';
  static const _legacyCodexTokenKey = 'codex.auth';
  final FlutterSecureStorage _storage;

  static LlmSettings get debugDefaults {
    if (!kDebugMode) {
      return const LlmSettings(baseUrl: '', model: '', apiKey: '');
    }
    return const LlmSettings(
      baseUrl: String.fromEnvironment('LLM_BASE_URL'),
      model: String.fromEnvironment('LLM_MODEL'),
      apiKey: String.fromEnvironment('LLM_API_KEY'),
    );
  }

  LlmPreset? detectPreset(LlmSettings settings) {
    for (final preset in llmPresets) {
      if (preset.id != 'custom' && preset.baseUrl == settings.baseUrl.trim()) {
        return preset;
      }
    }
    return presetById('custom');
  }

  Future<LlmSettings> load() async {
    final baseUrl = await _storage.read(key: _baseUrlKey);
    final model = await _storage.read(key: _modelKey);
    final apiKey = await _storage.read(key: _apiKeyKey);
    final legacyMode = await _storage.read(key: _legacyAuthModeKey);
    // Remove old device-code credentials, including installations that later
    // switched back to an API-key provider.
    await _storage.delete(key: _legacyCodexTokenKey);
    if (legacyMode == 'codexDeviceCode') {
      await clear();
      return const LlmSettings(baseUrl: '', model: '', apiKey: '');
    }
    if (legacyMode != null) await _storage.delete(key: _legacyAuthModeKey);
    final defaults = debugDefaults;
    return LlmSettings(
      baseUrl: baseUrl ?? defaults.baseUrl,
      model: model ?? defaults.model,
      apiKey: apiKey ?? defaults.apiKey,
    );
  }

  Future<void> save(LlmSettings settings) async {
    await _storage.write(key: _baseUrlKey, value: settings.baseUrl.trim());
    await _storage.write(key: _modelKey, value: settings.model.trim());
    await _storage.write(key: _apiKeyKey, value: settings.apiKey.trim());
  }

  Future<void> clear() async {
    // Explicit empty values must override debug defaults after a reset.
    await _storage.write(key: _baseUrlKey, value: '');
    await _storage.write(key: _modelKey, value: '');
    await _storage.write(key: _apiKeyKey, value: '');
    await _storage.delete(key: _legacyAuthModeKey);
    await _storage.delete(key: _legacyCodexTokenKey);
  }
}
