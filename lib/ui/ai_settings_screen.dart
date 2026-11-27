import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../data/chat_tools.dart';
import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';
import 'settings_scaffold.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key, required this.settingsRepository});

  final LlmSettingsRepository settingsRepository;

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late LlmPreset _preset;
  late final TextEditingController _baseUrl;
  late final TextEditingController _model;
  late final TextEditingController _apiKey;
  late final TextEditingController _exaKey;
  late final TextEditingController _braveKey;
  late final TextEditingController _tavilyKey;
  String _searchProvider = 'exa';
  TextEditingController get _selectedSearchKey => switch (_searchProvider) {
    'brave' => _braveKey,
    'tavily' => _tavilyKey,
    _ => _exaKey,
  };
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
    _exaKey = TextEditingController();
    _braveKey = TextEditingController();
    _tavilyKey = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await widget.settingsRepository.load();
      final exaKey = await widget.settingsRepository.loadExaKey();
      final braveKey = await widget.settingsRepository.loadBraveKey();
      final tavilyKey = await widget.settingsRepository.loadTavilyKey();
      final searchProvider = await widget.settingsRepository
          .loadSearchProvider();
      if (!mounted) return;
      setState(() {
        _preset =
            widget.settingsRepository.detectPreset(settings) ?? llmPresets.last;
        _baseUrl.text = settings.baseUrl;
        _model.text = settings.model;
        _apiKey.text = settings.apiKey;
        _exaKey.text = exaKey;
        _braveKey.text = braveKey;
        _tavilyKey.text = tavilyKey;
        _searchProvider = ['exa', 'brave', 'tavily'].contains(searchProvider)
            ? searchProvider
            : 'exa';
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
    _exaKey.dispose();
    _braveKey.dispose();
    _tavilyKey.dispose();
    super.dispose();
  }

  void _applyPreset(LlmPreset preset) {
    if (preset == _preset) return;
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) {
      DevmateHaptics.selection();
    }
    setState(() {
      _preset = preset;
      if (preset.id != 'custom') {
        _baseUrl.text = preset.baseUrl;
        _model.text = preset.defaultModel;
      }
      _testResult = null;
    });
  }

  Future<void> _choosePreset() async {
    final selected = await showCupertinoModalPopup<LlmPreset>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(sheetContext).brightness,
          primaryColor: context.colors.accent,
          scaffoldBackgroundColor: context.colors.canvas,
          barBackgroundColor: context.colors.surfaceRaised,
        ),
        child: CupertinoActionSheet(
          title: Text(context.l10n.providerLabel),
          actions: [
            for (final preset in llmPresets)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, preset),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(context.presetLabel(preset))),
                    if (preset == _preset) ...[
                      const SizedBox(width: 8),
                      const Icon(CupertinoIcons.check_mark, size: 18),
                    ],
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(context.l10n.cancelAction),
          ),
        ),
      ),
    );
    if (selected != null && mounted) _applyPreset(selected);
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
      await widget.settingsRepository.saveExaKey(_exaKey.text);
      await widget.settingsRepository.saveBraveKey(_braveKey.text);
      await widget.settingsRepository.saveTavilyKey(_tavilyKey.text);
      await widget.settingsRepository.saveSearchProvider(_searchProvider);
      if (!mounted) return;
      showDevmateNotice(
        context,
        context.l10n.settingsSaved,
        kind: DevmateNoticeKind.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _testResult = context.l10n.settingsSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    final settings = _collect();
    if (!settings.isConfigured) {
      setState(() => _testResult = context.l10n.fillAllFields);
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final error = await testLlmConnection(settings);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testResult = error == null
          ? context.l10n.connectionOk
          : context.llmErrorText(error);
    });
  }

  Future<void> _testSearch() async {
    if (_selectedSearchKey.text.trim().isEmpty) {
      setState(() => _testResult = context.l10n.exaKeyMissing);
      return;
    }
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final tools = ChatTools(
      exaKey: _exaKey.text.trim(),
      braveKey: _braveKey.text.trim(),
      tavilyKey: _tavilyKey.text.trim(),
      searchProvider: _searchProvider,
    );
    try {
      final result = await tools.execute(
        'search_web',
        '{"query":"Flutter documentation"}',
      );
      if (!mounted) return;
      setState(
        () => _testResult = result.contains('"error"')
            ? context.l10n.exaTestFailed
            : context.l10n.connectionOk,
      );
    } finally {
      tools.dispose();
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: settingsAppBar(context, context.l10n.settingsAiTitle),
    body: _loading
        ? const Center(child: DevmateSpinner(size: 28, strokeWidth: 2.5))
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                children: [
                  Eyebrow(
                    context.l10n.settingsEyebrow,
                    color: context.colors.muted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.keyPrivacyNote,
                    style: TextStyle(color: context.colors.muted, height: 1.5),
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.webCorsNote,
                      style: TextStyle(
                        color: context.colors.lavender,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!kIsWeb &&
                      Theme.of(context).platform == TargetPlatform.iOS)
                    DevmateSelectionField(
                      label: context.l10n.providerLabel,
                      value: context.presetLabel(_preset),
                      onPressed: _choosePreset,
                    )
                  else
                    DropdownButtonFormField<LlmPreset>(
                      initialValue: _preset,
                      items: [
                        for (final preset in llmPresets)
                          DropdownMenuItem(
                            value: preset,
                            child: Text(
                              kIsWeb && preset.worksInBrowser
                                  ? '${context.presetLabel(preset)} '
                                        '${context.l10n.worksInBrowserSuffix}'
                                  : context.presetLabel(preset),
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
                    decoration: devmateFieldDecoration(
                      context,
                      label: context.l10n.baseUrlLabel,
                      hint: context.l10n.baseUrlHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _model,
                    decoration: devmateFieldDecoration(
                      context,
                      label: context.l10n.modelLabel,
                      hint: context.l10n.modelHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _apiKey,
                    obscureText: true,
                    decoration: devmateFieldDecoration(
                      context,
                      label: context.l10n.apiKeyLabel,
                      hint: context.l10n.apiKeyHint,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _searchProvider,
                    decoration: InputDecoration(
                      labelText: context.l10n.searchProviderLabel,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'exa', child: Text('Exa')),
                      DropdownMenuItem(
                        value: 'brave',
                        child: Text('Brave Search'),
                      ),
                      DropdownMenuItem(value: 'tavily', child: Text('Tavily')),
                    ],
                    onChanged: (value) =>
                        setState(() => _searchProvider = value ?? 'exa'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: ValueKey(_searchProvider),
                    controller: _selectedSearchKey,
                    obscureText: true,
                    decoration: devmateFieldDecoration(
                      context,
                      label: context.l10n.searchKeyLabel,
                      hint: context.l10n.searchKeyHint,
                    ),
                  ),
                  if (kIsWeb && _searchProvider == 'brave') ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.braveWebNote,
                      style: TextStyle(
                        color: context.colors.lavender,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.exaPrivacyNote,
                    style: TextStyle(color: context.colors.muted, height: 1.5),
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
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _testing ? null : _testSearch,
                    child: Text(context.l10n.testSearchConnection),
                  ),
                  if (_testResult != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testResult!.endsWith('✓')
                            ? context.colors.accent
                            : context.colors.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
  );
}
