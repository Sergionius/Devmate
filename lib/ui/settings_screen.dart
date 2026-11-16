import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_preferences.dart';
import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';
import 'training_view_model.dart';

enum _ImportMode { replace, append }

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.onImport});

  final Future<String?> Function(_ImportMode mode, String source) onImport;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _working = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(_ImportMode mode) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    final error = await widget.onImport(mode, _controller.text);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, mode);
    } else {
      setState(() {
        _working = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: kIsWeb,
          minLines: 6,
          maxLines: 12,
          enabled: !_working,
          decoration: InputDecoration(hintText: l10n.pasteQuestionsJson),
        ),
        if (_error != null) ...[
          const SizedBox(height: DevmateSpacing.sm),
          Text(
            _error!,
            style: TextStyle(
              color: context.colors.error,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
        const SizedBox(height: DevmateSpacing.lg),
        if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: _working ? null : () => _submit(_ImportMode.append),
                child: Text(l10n.importAppendAction),
              ),
              const SizedBox(height: DevmateSpacing.sm),
              OutlinedButton(
                onPressed: _working ? null : () => _submit(_ImportMode.replace),
                child: Text(l10n.importReplaceAction),
              ),
              const SizedBox(height: DevmateSpacing.sm),
              TextButton(
                onPressed: _working ? null : () => Navigator.pop(context),
                child: Text(l10n.cancelAction),
              ),
            ],
          )
        else
          Wrap(
            alignment: WrapAlignment.end,
            spacing: DevmateSpacing.sm,
            runSpacing: DevmateSpacing.sm,
            children: [
              TextButton(
                onPressed: _working ? null : () => Navigator.pop(context),
                child: Text(l10n.cancelAction),
              ),
              OutlinedButton(
                onPressed: _working ? null : () => _submit(_ImportMode.append),
                child: Text(l10n.importAppendAction),
              ),
              FilledButton(
                onPressed: _working ? null : () => _submit(_ImportMode.replace),
                child: Text(l10n.importReplaceAction),
              ),
            ],
          ),
      ],
    );
  }
}

PreferredSizeWidget _settingsAppBar(
  BuildContext context,
  String title, {
  String fallback = '/settings',
}) => AppBar(
  title: Text(title),
  leading: kIsWeb
      ? BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(fallback);
            }
          },
        )
      : null,
);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.appLocale,
    this.aiDisabled,
    this.themeMode,
    this.appPreferences,
  });

  final ValueNotifier<Locale?>? appLocale;

  final ValueNotifier<bool>? aiDisabled;

  final ValueNotifier<ThemeMode>? themeMode;

  final AppPreferencesRepository? appPreferences;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppLanguage _language = AppLanguage.system;
  AppThemePreference _theme = AppThemePreference.dark;

  bool _aiDisabled = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
    _loadTheme();
    _loadAiDisabled();
    widget.aiDisabled?.addListener(_onAiDisabledChanged);
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aiDisabled != oldWidget.aiDisabled) {
      oldWidget.aiDisabled?.removeListener(_onAiDisabledChanged);
      widget.aiDisabled?.addListener(_onAiDisabledChanged);
      _aiDisabled = widget.aiDisabled?.value ?? _aiDisabled;
    }
  }

  @override
  void dispose() {
    widget.aiDisabled?.removeListener(_onAiDisabledChanged);
    super.dispose();
  }

  void _onAiDisabledChanged() {
    if (mounted) setState(() => _aiDisabled = widget.aiDisabled!.value);
  }

  Future<void> _loadAiDisabled() async {
    bool? disabled = widget.aiDisabled?.value;
    try {
      final saved = await widget.appPreferences?.loadAiDisabled();
      if (saved != null) disabled = saved;
    } catch (error) {
      debugPrint('SettingsScreen: failed to read AI-disabled setting: $error');
    }
    if (mounted && disabled != null && disabled != _aiDisabled) {
      final resolved = disabled;
      setState(() => _aiDisabled = resolved);
      final notifier = widget.aiDisabled;
      if (notifier != null && notifier.value != resolved) {
        notifier.value = resolved;
      }
    }
  }

  Future<void> _changeAiDisabled(bool disabled) async {
    if (disabled == _aiDisabled) return;
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) {
      DevmateHaptics.selection();
    }
    setState(() => _aiDisabled = disabled);
    widget.aiDisabled?.value = disabled;
    final preferences = widget.appPreferences;
    if (preferences == null) return;
    try {
      await preferences.saveAiDisabled(disabled);
    } catch (error) {
      debugPrint('SettingsScreen: failed to save AI-disabled setting: $error');
    }
  }

  Future<void> _loadLanguage() async {
    try {
      final language = await widget.appPreferences?.loadLanguage();
      if (mounted && language != null && _language != language) {
        setState(() => _language = language);
      }
    } catch (error) {
      debugPrint('SettingsScreen: failed to read language: $error');
    }
  }

  Future<void> _loadTheme() async {
    try {
      final theme = await widget.appPreferences?.loadTheme();
      if (mounted && theme != null && _theme != theme) {
        setState(() => _theme = theme);
      }
    } catch (error) {
      debugPrint('SettingsScreen: failed to read theme: $error');
    }
  }

  Future<void> _changeTheme(AppThemePreference theme) async {
    if (theme == _theme) return;
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) {
      DevmateHaptics.selection();
    }
    setState(() => _theme = theme);
    widget.themeMode?.value = theme.mode;
    final preferences = widget.appPreferences;
    if (preferences == null) return;
    try {
      await preferences.saveTheme(theme);
    } catch (error) {
      debugPrint('SettingsScreen: failed to save theme: $error');
    }
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    if (language == _language) return;
    if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS) {
      DevmateHaptics.selection();
    }
    setState(() => _language = language);
    widget.appLocale?.value = language.locale;
    final preferences = widget.appPreferences;
    if (preferences == null) return;
    try {
      await preferences.saveLanguage(language);
    } catch (error) {
      debugPrint('SettingsScreen: failed to save language: $error');
    }
  }

  Future<void> _chooseLanguage() async {
    final selected = await showCupertinoModalPopup<AppLanguage>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(sheetContext).brightness,
          primaryColor: context.colors.accent,
          scaffoldBackgroundColor: context.colors.canvas,
          barBackgroundColor: context.colors.surfaceRaised,
        ),
        child: CupertinoActionSheet(
          title: Text(context.l10n.settingsLanguage),
          actions: [
            for (final language in AppLanguage.values)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, language),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(switch (language) {
                      AppLanguage.system => context.l10n.settingsLanguageSystem,
                      AppLanguage.russian => 'Russian',
                      AppLanguage.english => 'English',
                    }),
                    if (language == _language) ...[
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
    if (selected != null && mounted) await _changeLanguage(selected);
  }

  String _themeLabel(AppThemePreference theme) => switch (theme) {
    AppThemePreference.dark => context.l10n.settingsThemeDark,
    AppThemePreference.light => context.l10n.settingsThemeLight,
    AppThemePreference.system => context.l10n.settingsThemeSystem,
  };

  Future<void> _chooseTheme() async {
    final selected = await showCupertinoModalPopup<AppThemePreference>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(sheetContext).brightness,
          primaryColor: context.colors.accent,
          scaffoldBackgroundColor: context.colors.canvas,
          barBackgroundColor: context.colors.surfaceRaised,
        ),
        child: CupertinoActionSheet(
          title: Text(context.l10n.settingsTheme),
          actions: [
            for (final theme in AppThemePreference.values)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, theme),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(_themeLabel(theme))),
                    if (theme == _theme) ...[
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
    if (selected != null && mounted) await _changeTheme(selected);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _settingsAppBar(context, context.l10n.settingsTitle, fallback: '/'),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
          children: [
            if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS)
              OutlinedButton(
                onPressed: _chooseLanguage,
                child: Row(
                  children: [
                    Expanded(child: Text(context.l10n.settingsLanguage)),
                    Text(switch (_language) {
                      AppLanguage.system => context.l10n.settingsLanguageSystem,
                      AppLanguage.russian => 'Russian',
                      AppLanguage.english => 'English',
                    }),
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.chevron_down, size: 16),
                  ],
                ),
              )
            else
              DropdownButtonFormField<AppLanguage>(
                initialValue: _language,
                items: [
                  DropdownMenuItem(
                    value: AppLanguage.system,
                    child: Text(context.l10n.settingsLanguageSystem),
                  ),
                  const DropdownMenuItem(
                    value: AppLanguage.russian,
                    child: Text('Russian'),
                  ),
                  const DropdownMenuItem(
                    value: AppLanguage.english,
                    child: Text('English'),
                  ),
                ],
                onChanged: (language) => _changeLanguage(language!),
                decoration: InputDecoration(
                  labelText: context.l10n.settingsLanguage,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              context.l10n.settingsLanguageRestartNote,
              style: TextStyle(color: context.colors.muted, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS)
              OutlinedButton(
                onPressed: _chooseTheme,
                child: Row(
                  children: [
                    Expanded(child: Text(context.l10n.settingsTheme)),
                    Text(_themeLabel(_theme)),
                    const SizedBox(width: 8),
                    const Icon(CupertinoIcons.chevron_down, size: 16),
                  ],
                ),
              )
            else
              DropdownButtonFormField<AppThemePreference>(
                initialValue: _theme,
                items: [
                  for (final theme in AppThemePreference.values)
                    DropdownMenuItem(
                      value: theme,
                      child: Text(_themeLabel(theme)),
                    ),
                ],
                onChanged: (theme) => _changeTheme(theme!),
                decoration: InputDecoration(
                  labelText: context.l10n.settingsTheme,
                ),
              ),
            const SizedBox(height: 24),
            Card(
              clipBehavior: Clip.antiAlias,
              child: CheckboxListTile(
                value: _aiDisabled,
                onChanged: (disabled) => _changeAiDisabled(disabled ?? false),
                title: Text(context.l10n.settingsDisableAi),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  if (!_aiDisabled) ...[
                    DevmatePressable(
                      onTap: () => context.push('/settings/ai'),
                      child: ListTile(
                        title: Text(context.l10n.settingsAiSection),
                        subtitle: Text(context.l10n.settingsAiSectionNote),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: context.colors.border,
                    ),
                  ],
                  DevmatePressable(
                    onTap: () => context.push('/settings/data'),
                    child: ListTile(
                      title: Text(context.l10n.settingsDataTitle),
                      subtitle: Text(context.l10n.settingsDataSectionNote),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _settingsAppBar(context, context.l10n.settingsAiTitle),
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
                    OutlinedButton(
                      onPressed: _choosePreset,
                      child: Row(
                        children: [
                          Expanded(child: Text(context.l10n.providerLabel)),
                          Flexible(
                            child: Text(
                              context.presetLabel(_preset),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(CupertinoIcons.chevron_down, size: 16),
                        ],
                      ),
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

class DataSettingsScreen extends StatefulWidget {
  const DataSettingsScreen({
    super.key,
    required this.settingsRepository,
    required this.catalog,
    required this.viewModel,
  });

  final LlmSettingsRepository settingsRepository;
  final TopicCatalog catalog;
  final TrainingViewModel viewModel;

  @override
  State<DataSettingsScreen> createState() => _DataSettingsScreenState();
}

class _DataSettingsScreenState extends State<DataSettingsScreen> {
  bool _working = false;

  Future<void> _exportQuestions() async {
    final json = widget.catalog.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    showDevmateNotice(
      context,
      context.l10n.questionsCopied,
      kind: DevmateNoticeKind.success,
    );
  }

  Future<void> _importQuestions() async {
    final imported = await showDevmateForm<_ImportMode>(
      context: context,
      title: context.l10n.importQuestions,
      builder: (_) => _ImportDialog(onImport: _runImport),
    );
    if (imported == null || !mounted) return;
    if (imported == _ImportMode.replace) {
      DevmateHaptics.destructiveActionCompleted(context);
    }
    final message = imported == _ImportMode.replace
        ? context.l10n.questionsImported
        : context.l10n.questionsAppended;
    showDevmateNotice(context, message, kind: DevmateNoticeKind.success);
  }

  Future<String?> _runImport(_ImportMode mode, String source) async {
    try {
      if (mode == _ImportMode.replace) {
        await widget.catalog.importJson(source);
        await widget.viewModel.resetProgress();
      } else {
        await widget.catalog.addJson(source);
      }
      return null;
    } on FormatException catch (error) {
      if (!mounted) return null;
      return '${context.l10n.importFailed}: ${error.message}';
    } catch (_) {
      if (!mounted) return null;
      return context.l10n.importFailed;
    }
  }

  Future<void> _shareInstruction() async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: context.l10n.agentJsonInstruction),
      );
    } catch (_) {
      if (!mounted) return;
      showDevmateNotice(
        context,
        context.l10n.shareFailed,
        kind: DevmateNoticeKind.error,
      );
    }
  }

  Future<void> _resetProgress() async {
    final confirmed = await showDevmateConfirm(
      context,
      title: context.l10n.resetProgress,
      message: context.l10n.resetProgressWarning,
      confirmLabel: context.l10n.resetProgress,
      cancelLabel: context.l10n.cancelAction,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.viewModel.resetProgress();
      if (!mounted) return;
      DevmateHaptics.destructiveActionCompleted(context);
      showDevmateNotice(
        context,
        context.l10n.resetProgressDone,
        kind: DevmateNoticeKind.success,
      );
    } catch (_) {
      if (!mounted) return;
      showDevmateNotice(
        context,
        context.l10n.resetProgressFailed,
        kind: DevmateNoticeKind.error,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resetAll() async {
    final confirmed = await showDevmateConfirm(
      context,
      title: context.l10n.resetAll,
      message: context.l10n.resetWarning,
      confirmLabel: context.l10n.resetAll,
      cancelLabel: context.l10n.cancelAction,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.catalog.reset();
      await widget.viewModel.resetProgress();
      await widget.settingsRepository.clear();
      if (!mounted) return;
      DevmateHaptics.destructiveActionCompleted(context);
      showDevmateNotice(
        context,
        context.l10n.resetDone,
        kind: DevmateNoticeKind.success,
      );
    } catch (_) {
      if (!mounted) return;
      showDevmateNotice(
        context,
        context.l10n.resetFailed,
        kind: DevmateNoticeKind.error,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: _settingsAppBar(context, context.l10n.settingsDataTitle),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
          children: [
            Text(
              context.l10n.questionsManagement,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.questionsJsonHint),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _working ? null : _exportQuestions,
              child: Text(context.l10n.exportQuestions),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _working ? null : _importQuestions,
              child: Text(context.l10n.importQuestions),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: SelectableText(context.l10n.agentJsonInstruction),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: context.l10n.shareInstruction,
                  onPressed: _shareInstruction,
                  icon: const Icon(Icons.share),
                ),
              ],
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _working ? null : _resetProgress,
              child: Text(context.l10n.resetProgress),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _working ? null : _resetAll,
              child: Text(context.l10n.resetAll),
            ),
          ],
        ),
      ),
    ),
  );
}
