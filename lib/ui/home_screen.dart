import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/llm_settings.dart';
import '../data/question_catalog.dart';
import '../domain/question.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'training_view_model.dart';

IconData iconForTopic(String id) => switch (id) {
  'frontend' => Icons.language_rounded,
  'flutter' => Icons.flutter_dash_rounded,
  'ios' => Icons.phone_iphone_rounded,
  'ai' => Icons.auto_awesome_rounded,
  'architecture' => Icons.account_tree_rounded,
  'complexity' => Icons.functions_rounded,
  'javascript' => Icons.code_rounded,
  'algorithms' => Icons.data_array_rounded,
  'testing' => Icons.science_rounded,
  _ => Icons.hub_rounded,
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.viewModel,
    required this.settingsRepository,
  });
  final TrainingViewModel viewModel;
  final LlmSettingsRepository settingsRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = questionCatalog.fold<int>(
      0,
      (sum, topic) => sum + topic.questions.length,
    );
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, _) {
            if (widget.viewModel.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Scrollbar(
                  controller: _scrollController,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                        sliver: SliverList.list(
                          children: [
                            _BrandHeader(
                              onOpenSettings: () => context.push('/settings'),
                            ),
                            const SizedBox(height: 38),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final intro = _Intro(
                                  onStart: () => _continue(context),
                                );
                                final progress = _ProgressPanel(
                                  completed: widget.viewModel.completed,
                                  total: total,
                                  points: widget.viewModel.points,
                                );
                                if (constraints.maxWidth < 700) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      intro,
                                      const SizedBox(height: 24),
                                      progress,
                                    ],
                                  );
                                }
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(flex: 6, child: intro),
                                    const SizedBox(width: 32),
                                    Expanded(flex: 4, child: progress),
                                  ],
                                );
                              },
                            ),
                            if (widget.viewModel.error != null) ...[
                              const SizedBox(height: 16),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.orangeAccent,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          switch (widget.viewModel.error!) {
                                            TrainingError.progressLoad =>
                                              context.l10n.progressLoadError,
                                            TrainingError.answerSave =>
                                              context.l10n.answerSaveError,
                                          },
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: widget.viewModel.load,
                                        child: Text(context.l10n.retry),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 40),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Eyebrow(
                                        context.l10n.libraryEyebrow,
                                        color: DevmateColors.muted,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        context.l10n.chooseTopic,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  context.l10n.totalQuestions(total),
                                  style: const TextStyle(
                                    color: DevmateColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.crossAxisExtent >= 700
                                ? 2
                                : 1;
                            return SliverGrid.builder(
                              itemCount: questionCatalog.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    mainAxisExtent: 146,
                                  ),
                              itemBuilder: (context, index) {
                                final topic = questionCatalog[index];
                                return _TopicTile(
                                  topic: topic,
                                  number: index + 1,
                                  completed: widget.viewModel.completedIn(
                                    topic,
                                  ),
                                  onTap: () =>
                                      context.push('/topic/${topic.id}'),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _continue(BuildContext context) {
    for (final topic in questionCatalog) {
      final next = topic.questions.indexWhere(
        (question) => widget.viewModel.scoreFor(question) == null,
      );
      if (next >= 0) {
        context.push('/topic/${topic.id}/practice/$next');
        return;
      }
    }
    final topic = questionCatalog.first;
    context.push('/topic/${topic.id}/practice/0');
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onOpenSettings});
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/branding/devmate_source.png',
          width: 42,
          height: 42,
          semanticLabel: context.l10n.logoSemantics,
        ),
      ),
      const SizedBox(width: 11),
      const Text(
        'devmate',
        style: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
      ),
      const Spacer(),
      const Icon(Icons.wifi_off_rounded, size: 15, color: DevmateColors.muted),
      const SizedBox(width: 6),
      Text(
        context.l10n.offlineBadge,
        style: TextStyle(
          color: DevmateColors.muted,
          fontSize: 11,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 10),
      IconButton(
        tooltip: context.l10n.aiSettings,
        onPressed: onOpenSettings,
        icon: const Icon(
          Icons.settings_rounded,
          size: 21,
          color: DevmateColors.muted,
        ),
      ),
    ],
  );
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Eyebrow(context.l10n.homeEyebrow),
      const SizedBox(height: 14),
      Text(
        context.l10n.homeTitle,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 14),
      Text(
        context.l10n.homeSubtitle,
        style: TextStyle(color: DevmateColors.muted, fontSize: 15, height: 1.5),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
        label: Text(context.l10n.continueTraining),
      ),
    ],
  );
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.completed,
    required this.total,
    required this.points,
  });
  final int completed;
  final int total;
  final int points;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: DevmateColors.surface,
      border: Border.all(color: DevmateColors.border),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.statsEyebrow, color: DevmateColors.muted),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$completed',
              style: const TextStyle(
                fontSize: 48,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -3,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 5, left: 5),
              child: Text(
                '/ $total',
                style: const TextStyle(
                  color: DevmateColors.muted,
                  fontSize: 18,
                ),
              ),
            ),
            const Spacer(),
            const Icon(Icons.bolt_rounded, color: DevmateColors.accent),
            Text(
              '$points XP',
              style: const TextStyle(
                color: DevmateColors.accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProgressTrack(value: completed / total),
        const SizedBox(height: 10),
        Text(
          context.l10n.statsCompletedLabel,
          style: TextStyle(color: DevmateColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({
    required this.topic,
    required this.number,
    required this.completed,
    required this.onTap,
  });
  final InterviewTopic topic;
  final int number;
  final int completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: DevmateColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: DevmateColors.border),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  number.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: DevmateColors.muted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(
                  iconForTopic(topic.id),
                  color: completed == topic.questions.length
                      ? DevmateColors.accent
                      : DevmateColors.lavender,
                  size: 20,
                ),
              ],
            ),
            const Spacer(),
            Text(
              topic.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              topic.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ProgressTrack(
                    value: completed / topic.questions.length,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$completed/${topic.questions.length}',
                  style: const TextStyle(
                    color: DevmateColors.muted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 15,
                  color: DevmateColors.muted,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
