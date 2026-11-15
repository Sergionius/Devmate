import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum LlmAuthMode { apiKey, codexDeviceCode }

LlmAuthMode authModeFromName(String? name) => LlmAuthMode.values.firstWhere(
  (mode) => mode.name == name,
  orElse: () => LlmAuthMode.apiKey,
);

class LlmSettings {
  const LlmSettings({
    required this.baseUrl,
    required this.model,
    required this.apiKey,
    this.authMode = LlmAuthMode.apiKey,
  });

  final String baseUrl;
  final String model;
  final String apiKey;
  final LlmAuthMode authMode;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      (authMode == LlmAuthMode.apiKey ? apiKey.trim().isNotEmpty : true);

  LlmSettings copyWith({
    String? baseUrl,
    String? model,
    String? apiKey,
    LlmAuthMode? authMode,
  }) => LlmSettings(
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
    apiKey: apiKey ?? this.apiKey,
    authMode: authMode ?? this.authMode,
  );

  Map<String, String> toMap() => {
    'baseUrl': baseUrl,
    'model': model,
    'apiKey': apiKey,
    'authMode': authMode.name,
  };

  static LlmSettings fromMap(Map<String, String> map) => LlmSettings(
    baseUrl: map['baseUrl'] ?? '',
    model: map['model'] ?? '',
    apiKey: map['apiKey'] ?? '',
    authMode: authModeFromName(map['authMode']),
  );
}

class LlmPreset {
  const LlmPreset(
    this.id,
    this.label,
    this.baseUrl,
    this.defaultModel, {
    this.worksInBrowser = false,
    this.authMode = LlmAuthMode.apiKey,
  });
  final String id;
  final String label;
  final String baseUrl;
  final String defaultModel;

  final bool worksInBrowser;

  final LlmAuthMode authMode;
}

const llmPresets = <LlmPreset>[
  LlmPreset(
    'codex',
    'ChatGPT Codex (подписка)',
    'https://chatgpt.com/backend-api/codex',
    'gpt-6-luna',
    authMode: LlmAuthMode.codexDeviceCode,
  ),
  LlmPreset(
    'zaiCoding',
    'z.ai GLM Coding (подписка)',
    'https://api.z.ai/api/coding/paas/v4',
    'glm-5.3-flash',
  ),
  LlmPreset(
    'zai',
    'z.ai API (оплата за токены)',
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
    'Ollama (локально)',
    'http://localhost:11434/v1',
    'llama3.1',
  ),
  LlmPreset('custom', 'Свой endpoint', '', ''),
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
  static const _authModeKey = 'llm.authMode';
  static const _baseUrlEnv = 'LLM_BASE_URL';
  static const _modelEnv = 'LLM_MODEL';
  static const _apiKeyEnv = 'LLM_API_KEY';

  final FlutterSecureStorage _storage;

  LlmSettings fromEnv() {
    try {
      return LlmSettings(
        baseUrl: dotenv.env[_baseUrlEnv] ?? '',
        model: dotenv.env[_modelEnv] ?? '',
        apiKey: dotenv.env[_apiKeyEnv] ?? '',
      );
    } catch (_) {
      return const LlmSettings(baseUrl: '', model: '', apiKey: '');
    }
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
    final env = fromEnv();
    final baseUrl = await _storage.read(key: _baseUrlKey);
    final model = await _storage.read(key: _modelKey);
    final apiKey = await _storage.read(key: _apiKeyKey);
    final authMode = await _storage.read(key: _authModeKey);
    return LlmSettings(
      baseUrl: baseUrl ?? env.baseUrl,
      model: model ?? env.model,
      apiKey: apiKey ?? env.apiKey,
      authMode: authMode == null
          ? LlmAuthMode.apiKey
          : authModeFromName(authMode),
    );
  }

  Future<void> save(LlmSettings settings) async {
    await _storage.write(key: _baseUrlKey, value: settings.baseUrl.trim());
    await _storage.write(key: _modelKey, value: settings.model.trim());
    await _storage.write(key: _apiKeyKey, value: settings.apiKey.trim());
    await _storage.write(key: _authModeKey, value: settings.authMode.name);
  }

  Future<void> clear() async {
    await _storage.delete(key: _baseUrlKey);
    await _storage.delete(key: _modelKey);
    await _storage.delete(key: _apiKeyKey);
    await _storage.delete(key: _authModeKey);
  }
}
