import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/topic_catalog.dart';
import '../domain/question.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';

class EditTopicScreen extends StatefulWidget {
  const EditTopicScreen({
    super.key,
    required this.catalog,
    required this.topicId,
  });

  final TopicCatalog catalog;
  final String topicId;

  @override
  State<EditTopicScreen> createState() => _EditTopicScreenState();
}

class _EditTopicScreenState extends State<EditTopicScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final topic = widget.catalog.topicById(widget.topicId);
    _title = TextEditingController(text: topic?.title ?? '');
    _description = TextEditingController(text: topic?.description ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editTopicTitle),
        actions: [
          IconButton(
            tooltip: l10n.editSaveTopic,
            onPressed: _saving ? null : _saveMeta,
            icon: const Icon(Icons.check_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.catalog,
        builder: (context, _) {
          final topic = widget.catalog.topicById(widget.topicId);
          if (topic == null) {
            return Center(child: Text(l10n.pageNotFound));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _title,
                style: TextStyle(color: context.colors.primary, fontSize: 17),
                decoration: devmateFieldDecoration(
                  context,
                  label: l10n.editTopicNameLabel,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _description,
                maxLines: 2,
                style: TextStyle(color: context.colors.primary, fontSize: 15),
                decoration: devmateFieldDecoration(
                  context,
                  label: l10n.editTopicDescLabel,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _saveMeta,
                icon: const Icon(Icons.check_rounded),
                label: Text(l10n.editSaveTopic),
              ),
              const SizedBox(height: 26),
              Eyebrow(l10n.questionsEyebrow, color: context.colors.muted),
              const SizedBox(height: 10),
              for (final question in topic.questions)
                _EditableQuestionTile(
                  question: question,
                  onEdit: () => _showQuestionDialog(question),
                  onDelete: () => _deleteQuestion(question.id),
                ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => _showQuestionDialog(),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.editAddQuestion),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveMeta() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      await widget.catalog.updateTopicMeta(
        widget.topicId,
        _title.text,
        _description.text,
      );
      if (!mounted) return;
      showDevmateNotice(
        context,
        l10n.editSaved,
        kind: DevmateNoticeKind.success,
      );
    } catch (_) {
      if (!mounted) return;
      showDevmateNotice(
        context,
        l10n.createSaveError,
        kind: DevmateNoticeKind.error,
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _deleteQuestion(String questionId) async {
    final l10n = context.l10n;
    final confirmed = await showDevmateConfirm(
      context,
      title: l10n.editDeleteQuestion,
      confirmLabel: l10n.editDeleteQuestion,
      cancelLabel: MaterialLocalizations.of(context).cancelButtonLabel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.catalog.deleteQuestion(questionId);
    } catch (_) {
      if (!mounted) return;
      showDevmateNotice(
        context,
        l10n.createSaveError,
        kind: DevmateNoticeKind.error,
      );
      return;
    }
    if (!mounted) return;
    DevmateHaptics.destructiveActionCompleted(context);
    showDevmateNotice(
      context,
      context.l10n.editSaved,
      kind: DevmateNoticeKind.success,
    );
  }

  Future<void> _showQuestionDialog([InterviewQuestion? existing]) async {
    final l10n = context.l10n;
    final saved = await showDevmateForm<bool>(
      context: context,
      title: existing == null
          ? l10n.editQuestionDialogTitleNew
          : l10n.editQuestionDialogTitleEdit,
      builder: (_) => _QuestionForm(
        initialPrompt: existing?.prompt ?? '',
        initialAnswer: existing?.answer ?? '',
        autofocusPrompt: existing == null,
        onSave: (prompt, answer) => _saveQuestion(existing, prompt, answer),
      ),
    );
    if (saved != true || !mounted) return;
    showDevmateNotice(
      context,
      context.l10n.editSaved,
      kind: DevmateNoticeKind.success,
    );
  }

  Future<String?> _saveQuestion(
    InterviewQuestion? existing,
    String prompt,
    String answer,
  ) async {
    try {
      if (existing == null) {
        await widget.catalog.addQuestionsToTopic(widget.topicId, [
          (prompt, answer),
        ]);
      } else {
        await widget.catalog.updateQuestion(existing.id, prompt, answer);
      }
      return null;
    } catch (_) {
      if (!mounted) return null;
      return context.l10n.createSaveError;
    }
  }
}

class _QuestionForm extends StatefulWidget {
  const _QuestionForm({
    required this.initialPrompt,
    required this.initialAnswer,
    required this.autofocusPrompt,
    required this.onSave,
  });

  final String initialPrompt;
  final String initialAnswer;

  final bool autofocusPrompt;

  final Future<String?> Function(String prompt, String answer) onSave;

  @override
  State<_QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends State<_QuestionForm> {
  late final TextEditingController _prompt = TextEditingController(
    text: widget.initialPrompt,
  );
  late final TextEditingController _answer = TextEditingController(
    text: widget.initialAnswer,
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _prompt.dispose();
    _answer.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final promptText = _prompt.text.trim();
    final answerText = _answer.text.trim();
    if (promptText.isEmpty || answerText.isEmpty) {
      setState(() => _error = context.l10n.editRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(promptText, answerText);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
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
          controller: _prompt,
          autofocus: widget.autofocusPrompt,
          maxLines: 3,
          minLines: 1,
          enabled: !_saving,
          style: TextStyle(color: context.colors.primary),
          decoration: devmateFieldDecoration(
            context,
            label: l10n.editPromptLabel,
          ),
        ),
        const SizedBox(height: DevmateSpacing.md),
        TextField(
          controller: _answer,
          maxLines: 5,
          minLines: 2,
          enabled: !_saving,
          style: TextStyle(color: context.colors.primary),
          decoration: devmateFieldDecoration(
            context,
            label: l10n.editAnswerLabel,
          ),
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
                onPressed: _saving ? null : _save,
                child: Text(l10n.editSave),
              ),
              const SizedBox(height: DevmateSpacing.sm),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
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
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.editSave),
              ),
            ],
          ),
      ],
    );
  }
}

class _EditableQuestionTile extends StatelessWidget {
  const _EditableQuestionTile({
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  final InterviewQuestion question;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Material(
      color: Colors.transparent,
      child: DevmatePressable(
        borderRadius: BorderRadius.circular(14),
        onTap: onEdit,
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
          title: Text(
            question.prompt,
            style: TextStyle(
              color: context.colors.primary,
              fontSize: 15,
              height: 1.35,
            ),
          ),
          subtitle: Text(
            question.answer,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.muted, fontSize: 13),
          ),
          trailing: IconButton(
            tooltip: context.l10n.editDeleteQuestion,
            icon: const Icon(Icons.delete_outline_rounded, size: 22),
            onPressed: onDelete,
          ),
        ),
      ),
    ),
  );
}
