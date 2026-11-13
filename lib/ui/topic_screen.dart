import 'package:flutter/material.dart';

import '../domain/question.dart';
import 'design_system.dart';
import 'home_screen.dart';
import 'practice_screen.dart';
import 'training_view_model.dart';

class TopicScreen extends StatelessWidget {
  const TopicScreen({super.key, required this.topic, required this.viewModel});
  final InterviewTopic topic;
  final TrainingViewModel viewModel;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Направление')),
    body: ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Scrollbar(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
              children: [
                Row(
                  children: [
                    const Eyebrow('БИБЛИОТЕКА / ТЕМА'),
                    const Spacer(),
                    Icon(
                      iconForTopic(topic.id),
                      color: DevmateColors.lavender,
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
                      ?.copyWith(color: DevmateColors.muted),
                ),
                const SizedBox(height: 24),
                ProgressTrack(
                  value: viewModel.completedIn(topic) / topic.questions.length,
                ),
                const SizedBox(height: 8),
                Text(
                  '${viewModel.completedIn(topic)} из ${topic.questions.length} вопросов пройдено',
                  style: const TextStyle(
                    color: DevmateColors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    final next = topic.questions.indexWhere(
                      (q) => viewModel.scoreFor(q) == null,
                    );
                    _openPractice(context, next < 0 ? 0 : next);
                  },
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    viewModel.completedIn(topic) == topic.questions.length
                        ? 'Повторить тему'
                        : 'Продолжить тренировку',
                  ),
                ),
                const SizedBox(height: 36),
                const Eyebrow('ВОПРОСЫ', color: DevmateColors.muted),
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
                                    topic.questions[index].prompt,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      height: 1.35,
                                    ),
                                  ),
                                  if (viewModel.scoreFor(
                                        topic.questions[index],
                                      ) !=
                                      null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      viewModel.scoreFor(
                                                topic.questions[index],
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
          topic: topic,
          initialIndex: index,
          viewModel: viewModel,
        ),
      ),
    );
  }
}
