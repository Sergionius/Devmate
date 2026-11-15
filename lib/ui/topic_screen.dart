import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/topic_catalog.dart';
import '../domain/question.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'home_screen.dart';
import 'training_view_model.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({
    super.key,
    required this.topic,
    required this.viewModel,
    required this.catalog,
  });
  final InterviewTopic topic;
  final TrainingViewModel viewModel;
  final TopicCatalog catalog;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _scrollController = ScrollController();
  bool _resettingProgress = false;

  Future<void> _resetTopicProgress(InterviewTopic topic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.resetTopicProgress),
        content: Text(context.l10n.resetTopicProgressWarning(topic.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.resetTopicProgress),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resettingProgress = true);
    try {
      await widget.viewModel.resetTopicProgress(topic);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.resetTopicProgressDone)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.resetProgressFailed)));
    } finally {
      if (mounted) setState(() => _resettingProgress = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.topicEyebrowDirection),

      automaticallyImplyLeading: !kIsWeb,
    ),
    body: ListenableBuilder(
      listenable: Listenable.merge([widget.viewModel, widget.catalog]),
      builder: (context, _) {
        final topic = widget.catalog.topicById(widget.topic.id) ?? widget.topic;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Scrollbar(
              controller: _scrollController,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                children: [
                  Row(
                    children: [
                      Eyebrow(context.l10n.topicEyebrow),
                      const Spacer(),
                      Icon(
                        iconForTopic(widget.topic.id),
                        color: DevmateColors.lavender,
                        size: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.topic.title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.topic.description,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: DevmateColors.muted),
                  ),
                  const SizedBox(height: 24),
                  ProgressTrack(
                    value:
                        widget.viewModel.completedIn(widget.topic) /
                        widget.topic.questions.length,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.topicProgress(
                      widget.viewModel.completedIn(widget.topic),
                      widget.topic.questions.length,
                    ),
                    style: const TextStyle(
                      color: DevmateColors.muted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      final next = widget.topic.questions.indexWhere(
                        (q) => widget.viewModel.scoreFor(q) == null,
                      );
                      _openPractice(context, next < 0 ? 0 : next);
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      widget.viewModel.completedIn(widget.topic) ==
                              widget.topic.questions.length
                          ? context.l10n.repeatTopic
                          : context.l10n.continueTraining,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/chat/topic/${topic.id}'),
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: Text(context.l10n.discussTopicWithAi),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/chat/create/${topic.id}'),
                    icon: const Icon(Icons.playlist_add_rounded, size: 20),
                    label: Text(context.l10n.appendChatButton),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/topic/${topic.id}/edit'),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: Text(context.l10n.editTopicButton),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed:
                        _resettingProgress ||
                            widget.viewModel.completedIn(topic) == 0
                        ? null
                        : () => _resetTopicProgress(topic),
                    icon: const Icon(Icons.restart_alt_rounded, size: 20),
                    label: Text(context.l10n.resetTopicProgress),
                  ),
                  const SizedBox(height: 36),
                  Eyebrow(
                    context.l10n.questionsEyebrow,
                    color: DevmateColors.muted,
                  ),
                  const SizedBox(height: 10),
                  for (
                    var index = 0;
                    index < topic.questions.length;
                    index++
                  ) ...[
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openPractice(context, index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 4,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  '${index + 1}'.padLeft(2, '0'),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: DevmateColors.muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.topic.questions[index].prompt,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                    if (widget.viewModel.scoreFor(
                                          topic.questions[index],
                                        ) !=
                                        null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        widget.viewModel.scoreFor(
                                                  topic.questions[index],
                                                ) ==
                                                10
                                            ? context.l10n.knownXp
                                            : context.l10n.repeatedXp,
                                        style: const TextStyle(
                                          color: DevmateColors.accent,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_outward_rounded,
                                color: DevmateColors.muted,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(color: DevmateColors.border, height: 1),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  void _openPractice(BuildContext context, int index) {
    context.push('/topic/${widget.topic.id}/practice/$index');
  }
}
