import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_preferences.dart';
import '../data/chat_history_repository.dart';
import '../data/data_transfer.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../data/transfer_defaults.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';
import 'settings_scaffold.dart';
import 'training_view_model.dart';

enum _ImportMode { replace, append }

enum _BackupMode { replace, merge }

/// Mode picker for a backup restore: shows what the file contains, then
/// merges it into the current data or replaces everything with it.
class _BackupImportDialog extends StatelessWidget {
  const _BackupImportDialog({required this.backup});

  final DevmateBackup backup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final topics = backup.catalog['topics'];
    final topicCount = topics is List ? topics.length : 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.backupSummary(topicCount, backup.scores.length)),
        if (backup.chats != null) ...[
          const SizedBox(height: DevmateSpacing.sm),
          Text(l10n.backupChatsInFile(backup.chats!.length)),
        ],
        const SizedBox(height: DevmateSpacing.lg),
        if (!kIsWeb && Theme.of(context).platform == TargetPlatform.iOS)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: () => Navigator.pop(context, _BackupMode.merge),
                child: Text(l10n.backupMergeAction),
              ),
              const SizedBox(height: DevmateSpacing.sm),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, _BackupMode.replace),
                child: Text(l10n.backupReplaceAction),
              ),
              const SizedBox(height: DevmateSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
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
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancelAction),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, _BackupMode.merge),
                child: Text(l10n.backupMergeAction),
              ),
              OutlinedButton(
                onPressed: () => Navigator.pop(context, _BackupMode.replace),
                child: Text(l10n.backupReplaceAction),
              ),
            ],
          ),
      ],
    );
  }
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.onImport, this.initialSource = ''});

  final Future<String?> Function(_ImportMode mode, String source) onImport;
  final String initialSource;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late final _controller = TextEditingController(text: widget.initialSource);
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

class DataSettingsScreen extends StatefulWidget {
  const DataSettingsScreen({
    super.key,
    required this.settingsRepository,
    required this.catalog,
    required this.viewModel,
    this.appPreferences,
    this.chatHistory,
    this.pickJsonFile = defaultPickJsonFile,
    this.shareJsonFile = defaultShareJsonFile,
  });

  final LlmSettingsRepository settingsRepository;
  final TopicCatalog catalog;
  final TrainingViewModel viewModel;
  final AppPreferencesRepository? appPreferences;
  final ChatHistoryRepository? chatHistory;

  /// Reads JSON from a user-picked file; `null` means the user canceled.
  final Future<String?> Function() pickJsonFile;

  /// Hands a JSON document to the platform share sheet as a file.
  final Future<void> Function(String fileName, String content) shareJsonFile;

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

  Future<void> _exportQuestionsToFile() async {
    setState(() => _working = true);
    try {
      await widget.shareJsonFile(
        transferFileName('devmate-questions', DateTime.now()),
        widget.catalog.exportJson(),
      );
    } catch (_) {
      if (!mounted) return;
      showDevmateNotice(
        context,
        context.l10n.shareFailed,
        kind: DevmateNoticeKind.error,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importQuestions() async {
    final imported = await showDevmateForm<_ImportMode>(
      context: context,
      title: context.l10n.importQuestions,
      builder: (_) => _ImportDialog(onImport: _runImport),
    );
    _finishQuestionsImport(imported);
  }

  Future<void> _importQuestionsFromFile() async {
    final source = await _readPickedFile();
    if (source == null || !mounted) return;
    final imported = await showDevmateForm<_ImportMode>(
      context: context,
      title: context.l10n.importQuestions,
      builder: (_) =>
          _ImportDialog(onImport: _runImport, initialSource: source),
    );
    _finishQuestionsImport(imported);
  }

  /// `null` on cancel; shows an error notice when the file can't be read.
  Future<String?> _readPickedFile() async {
    try {
      return await widget.pickJsonFile();
    } catch (_) {
      if (!mounted) return null;
      showDevmateNotice(
        context,
        context.l10n.fileReadFailed,
        kind: DevmateNoticeKind.error,
      );
      return null;
    }
  }

  void _finishQuestionsImport(_ImportMode? imported) {
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

  Future<void> _exportBackup() async {
    var includeChats = false;
    final choice = await showDevmateForm<bool>(
      context: context,
      title: context.l10n.exportBackup,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              title: Text(context.l10n.backupIncludeChats),
              value: includeChats,
              onChanged: (value) =>
                  setDialogState(() => includeChats = value ?? false),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, includeChats),
              child: Text(context.l10n.exportBackup),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.cancelAction),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _working = true);
    try {
      final now = DateTime.now();
      final ai = await widget.settingsRepository.load();
      final backup = DevmateBackup(
        catalog:
            jsonDecode(widget.catalog.exportJson()) as Map<String, dynamic>,
        scores: widget.viewModel.scores,
        exportedAt: now.toUtc().toIso8601String(),
        preferences: await widget.appPreferences?.exportBackup(),
        chats: choice ? await widget.chatHistory?.export() : null,
        ai: {
          if (ai.baseUrl.isNotEmpty) 'baseUrl': ai.baseUrl,
          if (ai.model.isNotEmpty) 'model': ai.model,
        },
      );
      await widget.shareJsonFile(
        transferFileName('devmate-backup', now),
        backup.encode(),
      );
    } catch (_) {
      if (!mounted) return;
      showDevmateNotice(
        context,
        context.l10n.shareFailed,
        kind: DevmateNoticeKind.error,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _importBackup() async {
    final source = await _readPickedFile();
    if (source == null || !mounted) return;
    final DevmateBackup backup;
    try {
      backup = DevmateBackup.parse(source);
      // Validate the catalog payload up front so a bad file never leaves
      // the catalog half-restored, and its details reach the user.
      widget.catalog.validateRestoreJson(jsonEncode(backup.catalog));
    } on FormatException catch (error) {
      showDevmateNotice(
        context,
        '${context.l10n.backupInvalid}: ${error.message}',
        kind: DevmateNoticeKind.error,
      );
      return;
    }
    final mode = await showDevmateForm<_BackupMode>(
      context: context,
      title: context.l10n.importBackup,
      builder: (_) => _BackupImportDialog(backup: backup),
    );
    if (mode == null || !mounted) return;
    setState(() => _working = true);
    try {
      if (mode == _BackupMode.replace) {
        await _applyBackupReplace(backup);
      } else {
        await _applyBackupMerge(backup);
      }
      if (!mounted) return;
      if (mode == _BackupMode.replace) {
        DevmateHaptics.destructiveActionCompleted(context);
      }
      showDevmateNotice(
        context,
        mode == _BackupMode.replace
            ? context.l10n.backupImportedReplace
            : context.l10n.backupImportedMerge,
        kind: DevmateNoticeKind.success,
      );
    } catch (_) {
      if (!mounted) return;
      showDevmateNotice(
        context,
        context.l10n.backupImportFailed,
        kind: DevmateNoticeKind.error,
      );
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _applyBackupReplace(DevmateBackup backup) async {
    await widget.catalog.restoreJson(jsonEncode(backup.catalog));
    await widget.viewModel.restoreProgress(backup.scores);
    await widget.appPreferences?.restoreBackup(backup.preferences ?? const {});
    if (backup.chats != null) {
      await widget.chatHistory?.import(backup.chats!, merge: false);
    }
    final ai = backup.ai;
    if (ai != null && (ai.containsKey('baseUrl') || ai.containsKey('model'))) {
      final current = await widget.settingsRepository.load();
      await widget.settingsRepository.save(
        current.copyWith(
          baseUrl: ai['baseUrl'] ?? current.baseUrl,
          model: ai['model'] ?? current.model,
        ),
      );
    }
  }

  Future<void> _applyBackupMerge(DevmateBackup backup) async {
    final topics = backup.catalog['topics'];
    if (topics is List && topics.isNotEmpty) {
      await widget.catalog.addJson(jsonEncode(backup.catalog));
    }
    await widget.viewModel.restoreProgress(backup.scores, merge: true);
    if (backup.chats != null) {
      await widget.chatHistory?.import(backup.chats!, merge: true);
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
    appBar: settingsAppBar(context, context.l10n.settingsDataTitle),
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
              onPressed: _working ? null : _exportQuestionsToFile,
              child: Text(context.l10n.exportQuestionsFile),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _working ? null : _importQuestions,
              child: Text(context.l10n.importQuestions),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _working ? null : _importQuestionsFromFile,
              child: Text(context.l10n.importQuestionsFile),
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
            Text(
              context.l10n.backupSectionTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(context.l10n.backupHint),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _working ? null : _exportBackup,
              child: Text(context.l10n.exportBackup),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _working ? null : _importBackup,
              child: Text(context.l10n.importBackup),
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
