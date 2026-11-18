import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/topic_catalog.dart';
import '../domain/question.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'home_screen.dart';
import 'platform_ui.dart';
import 'training_view_model.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({
    super.key,
    required this.topic,
    required this.viewModel,
    required this.catalog,
    this.aiDisabled,
  });
  final InterviewTopic topic;
  final TrainingViewModel viewModel;
  final TopicCatalog catalog;

  final ValueListenable<bool>? aiDisabled;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _scrollController = ScrollController();
  bool _resettingProgress = false;

  Future<void> _resetTopicProgress(InterviewTopic topic) async {
    final l10n = context.l10n;
    final confirmed = await showDevmateConfirm(
      context,
      title: l10n.resetTopicProgress,
      message: l10n.resetTopicProgressWarning(topic.title),
      confirmLabel: l10n.resetTopicProgress,
      cancelLabel: l10n.cancelAction,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _resettingProgress = true);
    try {
      await widget.viewModel.resetTopicProgress(topic);
      if (!mounted) return;
      DevmateHaptics.destructiveActionCompleted(context);
      showDevmateNotice(
        context,
        l10n.resetTopicProgressDone,
        kind: DevmateNoticeKind.success,
      );
    } catch (_) {
      if (!mounted) return;
      showDevmateNotice(
        context,
        l10n.resetProgressFailed,
        kind: DevmateNoticeKind.error,
      );
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
                        color: context.colors.lavender,
                        size: 28,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    topic.title,
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topic.description,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: context.colors.muted),
                  ),
                  const SizedBox(height: 24),
                  ProgressTrack(
                    value: topic.questions.isEmpty
                        ? 0
                        : widget.viewModel.completedIn(topic) /
                              topic.questions.length,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.topicProgress(
                      widget.viewModel.completedIn(topic),
                      topic.questions.length,
                    ),
                    style: TextStyle(color: context.colors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: topic.questions.isEmpty
                        ? null
                        : () {
                            final next = topic.questions.indexWhere(
                              (q) => widget.viewModel.scoreFor(q) == null,
                            );
                            _openPractice(context, next < 0 ? 0 : next);
                          },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      topic.questions.isNotEmpty &&
                              widget.viewModel.completedIn(topic) ==
                                  topic.questions.length
                          ? context.l10n.repeatTopic
                          : context.l10n.continueTraining,
                    ),
                  ),
                  DevmateAiVisibility(
                    aiDisabled: widget.aiDisabled,
                    topGap: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/chat/topic/${topic.id}'),
                      icon: const Icon(Icons.chat_rounded, size: 20),
                      label: Text(context.l10n.discussTopicWithAi),
                    ),
                  ),
                  DevmateAiVisibility(
                    aiDisabled: widget.aiDisabled,
                    topGap: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/chat/create/${topic.id}'),
                      icon: const Icon(Icons.playlist_add_rounded, size: 20),
                      label: Text(context.l10n.appendChatButton),
                    ),
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
                    color: context.colors.muted,
                  ),
                  const SizedBox(height: 10),
                  for (
                    var index = 0;
                    index < topic.questions.length;
                    index++
                  ) ...[
                    DevmatePressable(
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
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: context.colors.muted,
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
                                    topic.questions[index].prompt,
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
                                      style: TextStyle(
                                        color: context.colors.accent,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.arrow_outward_rounded,
                              color: context.colors.muted,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(color: context.colors.border, height: 1),
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
