import 'package:flutter/material.dart';

import '../domain/question.dart';
import 'design_system.dart';
import 'home_screen.dart';
import 'practice_screen.dart';
import 'training_view_model.dart';

class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key, required this.topic, required this.viewModel});
  final InterviewTopic topic;
  final TrainingViewModel viewModel;

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Направление')),
    body: ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) => Center(
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
                    const Eyebrow('БИБЛИОТЕКА / ТЕМА'),
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
                  '${widget.viewModel.completedIn(widget.topic)} из ${widget.topic.questions.length} вопросов пройдено',
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
                        ? 'Повторить тему'
                        : 'Продолжить тренировку',
                  ),
                ),
                const SizedBox(height: 36),
                const Eyebrow('ВОПРОСЫ', color: DevmateColors.muted),
                const SizedBox(height: 10),
                for (
                  var index = 0;
                  index < widget.topic.questions.length;
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
                                        widget.topic.questions[index],
                                      ) !=
                                      null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.viewModel.scoreFor(
                                                widget.topic.questions[index],
                                              ) ==
                                              10
                                          ? 'Знаю · 10 XP'
                                          : 'Повторил · 5 XP',
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
      ),
    ),
  );

  void _openPractice(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeScreen(
          topic: widget.topic,
          initialIndex: index,
          viewModel: widget.viewModel,
        ),
      ),
    );
  }
}
