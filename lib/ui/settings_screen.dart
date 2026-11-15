import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/codex_auth.dart';
import '../data/app_preferences.dart';
import '../data/codex_chat_provider.dart';
import '../data/codex_token_store.dart';
import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';
import 'training_view_model.dart';

/// Режим импорта вставленного JSON: полная замена каталога или добавление.
enum _ImportMode { replace, append }

/// Адаптивная форма вставки JSON: на iOS — модальный лист UI kit, на
/// Android и web — диалог в общей теме. Владеет своим контроллером, чтобы
/// dispose не происходил во время анимации закрытия; сам запускает импорт
/// через [onImport], поэтому при ошибке введённый текст и сообщение об
/// ошибке остаются в форме.
class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.onImport});

  /// Выполняет импорт; возвращает текст ошибки для показа внутри формы
  /// или null при успехе (тогда форма закрывается).
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
          // На web фокус сразу в поле; на телефонах клавиатуру не
          // выскамываем поверх листа.
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

/// AppBar раздела настроек. На web, где мобильные жесты возврата недоступны,
/// показывается явная кнопка «назад»; на телефонах возврат подразумевается
/// платформой (включая iOS edge-swipe), а при глубокой ссылке ведёт на
/// [fallback].
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

/// Обзор настроек `/settings`: язык приложения, отключение AI и переходы к
/// разделам AI-провайдера и вопросов/данных.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.appLocale,
    this.aiDisabled,
    this.themeMode,
    this.appPreferences,
  });

  /// Живой выбор языка из [AppLanguage]; `null` — язык системы.
  final ValueNotifier<Locale?>? appLocale;

  /// Глобальное отключение AI; когда включено, раздел AI-провайдера скрыт.
  final ValueNotifier<bool>? aiDisabled;

  /// Живой режим темы: тёмная/светлая/как на устройстве.
  final ValueNotifier<ThemeMode>? themeMode;

  final AppPreferencesRepository? appPreferences;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppLanguage _language = AppLanguage.system;
  AppThemePreference _theme = AppThemePreference.dark;

  /// Локальная копия общего нотифаера, чтобы чекбокс менялся и при
  /// переключении из других мест.
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
      debugPrint('SettingsScreen: чтение отключения AI не удалось: $error');
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

  /// Применяет отключение мгновенно (общий нотифаер скрывает AI-кнопки на
  /// всех экранах) и сохраняет выбор; как и язык — без кнопки «Сохранить».
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
      debugPrint('SettingsScreen: сохранение отключения AI не удалось: $error');
    }
  }

  Future<void> _loadLanguage() async {
    try {
      final language = await widget.appPreferences?.loadLanguage();
      if (mounted && language != null && _language != language) {
        setState(() => _language = language);
      }
    } catch (error) {
      debugPrint('SettingsScreen: чтение языка не удалось: $error');
    }
  }

  Future<void> _loadTheme() async {
    try {
      final theme = await widget.appPreferences?.loadTheme();
      if (mounted && theme != null && _theme != theme) {
        setState(() => _theme = theme);
      }
    } catch (error) {
      debugPrint('SettingsScreen: чтение темы не удалось: $error');
    }
  }

  /// Применяет режим темы мгновенно (общий нотифаер пересобирает
  /// MaterialApp) и сохраняет выбор; сбой сохранения не отменяет смену.
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
      debugPrint('SettingsScreen: сохранение темы не удалось: $error');
    }
  }

  /// Применяет язык мгновенно и сохраняет выбор; смена языка —
  /// приложенческая настройка, кнопка «Сохранить» ей не нужна.
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
      debugPrint('SettingsScreen: сохранение языка не удалось: $error');
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
                      AppLanguage.russian => 'Русский',
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

  /// Метка режима темы для кнопки-селектора и action sheet.
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
                      AppLanguage.russian => 'Русский',
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
                    child: Text('Русский'),
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

/// Раздел `/settings/ai`: провайдер, ключи, Codex-авторизация,
/// сохранение и тест соединения.
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
    authMode: _preset.authMode,
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

    final error = settings.authMode == LlmAuthMode.codexDeviceCode
        ? await testCodexConnection(settings)
        : await testLlmConnection(settings);
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
                  if (_preset.authMode == LlmAuthMode.codexDeviceCode)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: CodexLoginCard(onChanged: () {}),
                    )
                  else ...[
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
                  ],
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

/// Раздел `/settings/data`: экспорт/импорт вопросов и сброс данных.
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
    // Успех импорта по-прежнему завершается уведомлением экрана; ошибки
    // остаются внутри формы вместе с введённым текстом.
    final message = imported == _ImportMode.replace
        ? context.l10n.questionsImported
        : context.l10n.questionsAppended;
    showDevmateNotice(context, message, kind: DevmateNoticeKind.success);
  }

  /// Выполняет импорт и возвращает текст ошибки для показа внутри формы
  /// или null при успехе. «Добавить» сохраняет прогресс, «Заменить всё»
  /// сбрасывает его — как прежде.
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

  /// Открывает системное меню «Поделиться» с точным текстом инструкции
  /// для агента на текущем языке; отмена и ошибки не ломают экран.
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
      await CodexAuth.shared.logout();
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

class CodexLoginCard extends StatefulWidget {
  const CodexLoginCard({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  State<CodexLoginCard> createState() => _CodexLoginCardState();
}

class _CodexLoginCardState extends State<CodexLoginCard> {
  bool _loading = true;
  CodexTokens? _tokens;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    final tokens = await CodexAuth.shared.load();
    if (!mounted) return;
    setState(() {
      _tokens = tokens;
      _loading = false;
    });
  }

  Future<void> _login() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CodexDeviceLoginSheet(),
    );
    await _reload();
    widget.onChanged();
  }

  Future<void> _logout() async {
    await CodexAuth.shared.logout();
    await _reload();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: _loading
          ? const Center(child: DevmateSpinner())
          : kIsWeb
          ? Text(
              context.l10n.codexWebUnsupported,
              style: TextStyle(color: context.colors.muted, height: 1.5),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tokens == null) ...[
                  Text(
                    context.l10n.codexLoginHint,
                    style: TextStyle(color: context.colors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.login),
                    label: Text(context.l10n.codexLogin),
                  ),
                ] else ...[
                  Text(
                    context.l10n.codexLoggedInUntil(
                      DateFormat('dd.MM.yyyy HH:mm').format(_tokens!.expiresAt),
                    ),
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _logout,
                    child: Text(context.l10n.codexLogout),
                  ),
                ],
              ],
            ),
    ),
  );
}

class CodexDeviceLoginSheet extends StatefulWidget {
  const CodexDeviceLoginSheet({super.key});

  @override
  State<CodexDeviceLoginSheet> createState() => _CodexDeviceLoginSheetState();
}

class _CodexDeviceLoginSheetState extends State<CodexDeviceLoginSheet> {
  final Completer<void> _cancel = Completer<void>();
  CodexDeviceCode? _code;
  bool _done = false;
  bool _closed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final tokens = await runCodexDeviceLogin(
        api: CodexDeviceAuthApi(),
        onCode: (code) {
          if (mounted) setState(() => _code = code);
        },
        cancel: _cancel,
      );
      await CodexAuth.shared.completeLogin(tokens);
      if (!mounted) return;
      setState(() => _done = true);
    } on CodexAuthException catch (error) {
      if (!mounted) return;
      if (error.kind == CodexAuthErrorKind.sessionExpired &&
          _cancel.isCompleted) {
        Navigator.of(context).pop();
        return;
      }
      setState(
        () => _error = switch (error.kind) {
          CodexAuthErrorKind.network => context.l10n.codexErrorNetwork,
          CodexAuthErrorKind.invalidResponse =>
            context.l10n.codexErrorInvalidResponse,
          CodexAuthErrorKind.rejected => context.l10n.codexErrorRejected,
          CodexAuthErrorKind.sessionExpired =>
            context.l10n.codexErrorSessionExpired,
          CodexAuthErrorKind.timeout => context.l10n.codexErrorTimeout,
        },
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _openVerificationPage() async {
    final url = Uri.parse(_code!.verificationUri);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: _code!.userCode));
    if (!mounted) return;
    showDevmateNotice(
      context,
      context.l10n.codexCopied,
      kind: DevmateNoticeKind.success,
    );
  }

  void _dismiss() {
    if (_closed) return;
    _closed = true;
    if (!_cancel.isCompleted) _cancel.complete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.codexLogin),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_code != null) ...[
          Text(context.l10n.codexDeviceCodeLabel),
          const SizedBox(height: 4),
          SelectableText(
            _code!.userCode,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: _copyCode,
                icon: const Icon(Icons.copy),
                label: Text(context.l10n.codexCopyCode),
              ),
              TextButton.icon(
                onPressed: _openVerificationPage,
                icon: const Icon(Icons.open_in_new),
                label: Text(context.l10n.codexOpenLoginPage),
              ),
            ],
          ),
        ],
        if (_done)
          Row(
            children: [
              Icon(Icons.check_circle, color: context.colors.accent),
              const SizedBox(width: 8),
              Text(context.l10n.codexLoginSuccess),
            ],
          )
        else if (_error != null)
          Text(
            context.l10n.codexLoginError(_error!),
            style: TextStyle(color: context.colors.error, height: 1.5),
          )
        else if (_code != null)
          Row(
            children: [
              const DevmateSpinner(size: 16, strokeWidth: 2),
              const SizedBox(width: 12),
              Text(context.l10n.codexWaitingApproval),
            ],
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: _done ? () => Navigator.of(context).pop() : _dismiss,
        child: Text(
          _done
              ? MaterialLocalizations.of(context).okButtonLabel
              : context.l10n.codexLoginCancelled,
        ),
      ),
    ],
  );
}
