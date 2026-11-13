import 'package:flutter/material.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import 'design_system.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settingsRepository});
  final LlmSettingsRepository settingsRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late LlmPreset _preset;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController();
    _model = TextEditingController();
    _apiKey = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await widget.settingsRepository.load();
      if (!mounted) return;
      setState(() {
        _preset =
            widget.settingsRepository.detectPreset(settings) ?? llmPresets.last;
        _baseUrl.text = settings.baseUrl;
        _model.text = settings.model;
        _apiKey.text = settings.apiKey;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _preset = llmPresets.last;
        _loading = false;
        _testResult =
            'Не удалось прочитать настройки. Проверьте доступность хранилища.';
      });
    }
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  void _applyPreset(LlmPreset preset) {
    setState(() {
      _preset = preset;
      if (preset.id != 'custom') {
        _baseUrl.text = preset.baseUrl;
        _model.text = preset.defaultModel;
      }
      _testResult = null;
    });
  }

  LlmSettings _collect() => LlmSettings(
    baseUrl: _baseUrl.text,
    model: _model.text,
    apiKey: _apiKey.text,
  );

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _testResult = null;
    });
    try {
      await widget.settingsRepository.save(_collect());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Настройки сохранены на этом устройстве.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () =>
            _testResult = 'Не удалось сохранить настройки на этом устройстве.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    if (!_collect().isConfigured) {
      setState(() => _testResult = 'Заполните URL, модель и API-ключ.');
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final error = await testLlmConnection(_collect());
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = error ?? 'Соединение работает ✓';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI-провайдер (BYOK)')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                children: [
                  const Eyebrow(
                    'ЛЮБОЙ OPENAI-СОВМЕСТИМЫЙ ENDPOINT',
                    color: DevmateColors.muted,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ключ хранится только на этом устройстве и уходит напрямую выбранному провайдеру. На web провайдер должен разрешать CORS.',
                    style: TextStyle(color: DevmateColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<LlmPreset>(
                    initialValue: _preset,
                    items: [
                      for (final preset in llmPresets)
                        DropdownMenuItem(
                          value: preset,
                          child: Text(preset.label),
                        ),
                    ],
                    onChanged: (preset) => _applyPreset(preset!),
                    decoration: const InputDecoration(labelText: 'Провайдер'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _baseUrl,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://api.z.ai/api/paas/v4',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _model,
                    decoration: const InputDecoration(
                      labelText: 'Модель',
                      hintText: 'glm-5.3-flash',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKey,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'API-ключ',
                      hintText: 'Введите ваш ключ',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Сохраняем...' : 'Сохранить'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _testing ? null : _test,
                    child: Text(
                      _testing ? 'Проверяем...' : 'Проверить соединение',
                    ),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testResult!.endsWith('✓')
                            ? DevmateColors.accent
                            : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
  );
}
