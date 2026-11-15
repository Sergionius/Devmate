import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'training_view_model.dart';

/// Режим импорта вставленного JSON: полная замена каталога или добавление.
enum _ImportMode { replace, append }

/// Диалог вставки JSON: возвращает режим импорта и введённый текст.
/// Владеет своим контроллером, чтобы dispose не происходил во время
/// анимации закрытия диалога.
class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(_ImportMode mode) =>
      Navigator.pop(context, (mode, _controller.text));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.importQuestions),
    content: SizedBox(
      width: 560,
      child: TextField(
        controller: _controller,
        maxLines: 10,
        decoration: InputDecoration(hintText: context.l10n.pasteQuestionsJson),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.l10n.cancelAction),
      ),
      OutlinedButton(
        onPressed: () => _submit(_ImportMode.append),
        child: Text(context.l10n.importAppendAction),
      ),
      FilledButton(
        onPressed: () => _submit(_ImportMode.replace),
        child: Text(context.l10n.importReplaceAction),
      ),
    ],
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settingsRepository,
    this.catalog,
    this.viewModel,
    this.appLocale,
    this.appPreferences,
  });
  final LlmSettingsRepository settingsRepository;
  final TopicCatalog? catalog;
  final TrainingViewModel? viewModel;

  /// Живой выбор языка из [AppLanguage]; `null` — язык системы.
  final ValueNotifier<Locale?>? appLocale;

  final AppPreferencesRepository? appPreferences;

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
  bool _working = false;
  String? _testResult;
  AppLanguage _language = AppLanguage.system;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController();
    _model = TextEditingController();
    _apiKey = TextEditingController();
    _load();
  }

  /// Применяет язык мгновенно и сохраняет выбор; смена языка —
  /// приложенческая настройка, кнопка «Сохранить» ей не нужна.
  Future<void> _changeLanguage(AppLanguage language) async {
    if (language == _language) return;
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

  Future<void> _load() async {
    try {
      final language = await widget.appPreferences?.loadLanguage();
      if (mounted && language != null && _language != language) {
        setState(() => _language = language);
      }
    } catch (error) {
      debugPrint('SettingsScreen: чтение языка не удалось: $error');
    }
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

  Future<void> _exportQuestions() async {
    final json = widget.catalog!.exportJson();
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.questionsCopied)));
  }

  Future<void> _importQuestions() async {
    final result = await showDialog<(_ImportMode, String)>(
      context: context,
      builder: (_) => const _ImportDialog(),
    );
    if (result == null || !mounted) return;
    final (mode, source) = result;
    setState(() => _working = true);
    try {
      if (mode == _ImportMode.replace) {
        await widget.catalog!.importJson(source);
        await widget.viewModel!.resetProgress();
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.questionsImported)));
      } else {
        await widget.catalog!.addJson(source);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.questionsAppended)));
      }
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.importFailed}: ${error.message}'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.importFailed)));
    } finally {
      if (mounted) setState(() => _working = false);
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.shareFailed)));
    }
  }

  Future<void> _resetProgress() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.resetProgress),
        content: Text(context.l10n.resetProgressWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.resetProgress),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.viewModel!.resetProgress();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.resetProgressDone)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.resetProgressFailed)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resetAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.resetAll),
        content: Text(context.l10n.resetWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.resetAll),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.catalog!.reset();
      await widget.viewModel!.resetProgress();
      await widget.settingsRepository.clear();
      await CodexAuth.shared.logout();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.resetDone)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.resetFailed)));
    } finally {
      if (mounted) setState(() => _working = false);
    }
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
                    style: TextStyle(color: DevmateColors.muted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
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
                      decoration: InputDecoration(
                        labelText: context.l10n.apiKeyLabel,
                        hintText: context.l10n.apiKeyHint,
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
                  if (widget.catalog != null && widget.viewModel != null) ...[
                    const SizedBox(height: 32),
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
                          child: SelectableText(
                            context.l10n.agentJsonInstruction,
                          ),
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
          ? const Center(child: CircularProgressIndicator())
          : kIsWeb
          ? Text(
              context.l10n.codexWebUnsupported,
              style: TextStyle(color: DevmateColors.muted, height: 1.5),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tokens == null) ...[
                  Text(
                    context.l10n.codexLoginHint,
                    style: TextStyle(color: DevmateColors.muted, height: 1.5),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.codexCopied)));
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
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(context.l10n.codexLoginSuccess),
            ],
          )
        else if (_error != null)
          Text(
            context.l10n.codexLoginError(_error!),
            style: const TextStyle(color: Colors.orangeAccent, height: 1.5),
          )
        else if (_code != null)
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
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
