import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../l10n/l10n.dart';
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
        _testResult = context.l10n.settingsLoadError;
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.settingsSaved)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _testResult = context.l10n.settingsSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    if (!_collect().isConfigured) {
      setState(() => _testResult = context.l10n.fillAllFields);
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
      _testResult = error == null
          ? context.l10n.connectionOk
          : context.llmErrorText(error);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.settingsTitle)),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                children: [
                  Eyebrow(
                    context.l10n.settingsEyebrow,
                    color: DevmateColors.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.keyPrivacyNote,
                    style: TextStyle(color: DevmateColors.muted, height: 1.5),
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.webCorsNote,
                      style: TextStyle(
                        color: DevmateColors.lavender,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  DropdownButtonFormField<LlmPreset>(
                    initialValue: _preset,
                    items: [
                      for (final preset in llmPresets)
                        DropdownMenuItem(
                          value: preset,
                          child: Text(
                            kIsWeb && preset.worksInBrowser
                                ? '${preset.label} ${context.l10n.worksInBrowserSuffix}'
                                : preset.label,
                          ),
                        ),
                    ],
                    onChanged: (preset) => _applyPreset(preset!),
                    decoration: InputDecoration(
                      labelText: context.l10n.providerLabel,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _baseUrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.baseUrlLabel,
                      hintText: context.l10n.baseUrlHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _model,
                    decoration: InputDecoration(
                      labelText: context.l10n.modelLabel,
                      hintText: context.l10n.modelHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKey,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.apiKeyLabel,
                      hintText: context.l10n.apiKeyHint,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? context.l10n.saving : context.l10n.save,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _testing ? null : _test,
                    child: Text(
                      _testing
                          ? context.l10n.testing
                          : context.l10n.testConnection,
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
