import 'package:flutter/material.dart';

import '../data/topic_catalog.dart';
import '../domain/question.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';

/// Ручное редактирование темы: название/описание и вопросы.
/// Работает одинаково для встроенных и пользовательских тем —
/// правки хранятся оверлеями в TopicCatalog.
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
                style: const TextStyle(
                  color: DevmateColors.primary,
                  fontSize: 17,
                ),
                decoration: InputDecoration(labelText: l10n.editTopicNameLabel),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _description,
                maxLines: 2,
                style: const TextStyle(
                  color: DevmateColors.primary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(labelText: l10n.editTopicDescLabel),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _saving ? null : _saveMeta,
                icon: const Icon(Icons.check_rounded),
                label: Text(l10n.editSaveTopic),
              ),
              const SizedBox(height: 26),
              Eyebrow(l10n.questionsEyebrow, color: DevmateColors.muted),
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
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.catalog.updateTopicMeta(
        widget.topicId,
        _title.text,
        _description.text,
      );
      messenger.showSnackBar(SnackBar(content: Text(l10n.editSaved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.createSaveError)));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _deleteQuestion(String questionId) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: DevmateColors.surface,
        title: Text(l10n.editDeleteQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.editDeleteQuestion),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.catalog.deleteQuestion(questionId);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.createSaveError)));
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(l10n.editSaved)));
  }

  Future<void> _showQuestionDialog([InterviewQuestion? existing]) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final prompt = TextEditingController(text: existing?.prompt ?? '');
    final answer = TextEditingController(text: existing?.answer ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: DevmateColors.surface,
        title: Text(
          existing == null
              ? l10n.editQuestionDialogTitleNew
              : l10n.editQuestionDialogTitleEdit,
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: prompt,
                maxLines: 3,
                minLines: 1,
                autofocus: existing == null,
                style: const TextStyle(color: DevmateColors.primary),
                decoration: InputDecoration(labelText: l10n.editPromptLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answer,
                maxLines: 5,
                minLines: 2,
                style: const TextStyle(color: DevmateColors.primary),
                decoration: InputDecoration(labelText: l10n.editAnswerLabel),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.editSave),
          ),
        ],
      ),
    );
    final promptText = prompt.text.trim();
    final answerText = answer.text.trim();
    prompt.dispose();
    answer.dispose();
    if (saved != true) return;
    if (promptText.isEmpty || answerText.isEmpty) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.editRequired)));
      return;
    }
    try {
      if (existing == null) {
        await widget.catalog.addQuestionsToTopic(widget.topicId, [
          (promptText, answerText),
        ]);
      } else {
        await widget.catalog.updateQuestion(
          existing.id,
          promptText,
          answerText,
        );
      }
      messenger.showSnackBar(SnackBar(content: Text(l10n.editSaved)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.createSaveError)));
    }
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
      color: DevmateColors.surface,
      border: Border.all(color: DevmateColors.border),
      borderRadius: BorderRadius.circular(14),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
      title: Text(
        question.prompt,
        style: const TextStyle(
          color: DevmateColors.primary,
          fontSize: 15,
          height: 1.35,
        ),
      ),
      subtitle: Text(
        question.answer,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: DevmateColors.muted, fontSize: 13),
      ),
      onTap: onEdit,
      trailing: IconButton(
        tooltip: context.l10n.editDeleteQuestion,
        icon: const Icon(Icons.delete_outline_rounded, size: 22),
        onPressed: onDelete,
      ),
    ),
  );
}
