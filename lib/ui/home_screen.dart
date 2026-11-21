import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../domain/question.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';
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
    required this.catalog,
    required this.settingsRepository,
    this.aiDisabled,
  });
  final TrainingViewModel viewModel;
  final TopicCatalog catalog;
  final LlmSettingsRepository settingsRepository;

  final ValueListenable<bool>? aiDisabled;

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
    final total = widget.catalog.topics.fold<int>(
      0,
      (sum, topic) => sum + topic.questions.length,
    );
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.viewModel,
            widget.catalog,
            widget.aiDisabled,
          ]),
          builder: (context, _) {
            final aiDisabled = widget.aiDisabled?.value ?? false;
            if (widget.viewModel.loading) {
              return const Center(
                child: DevmateSpinner(size: 28, strokeWidth: 2.5),
              );
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
                              onOpenSearch: () => context.push('/search'),
                            ),
                            const SizedBox(height: 38),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final intro = _Intro(
                                  onStart: total == 0
                                      ? null
                                      : () => _continue(context),
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
                                      Icon(
                                        Icons.error_outline,
                                        color: context.colors.error,
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
                            const SizedBox(height: 24),
                            if (!aiDisabled) ...[
                              const _FreeChatCard(),
                              const SizedBox(height: 12),
                              const _CreateTopicCard(),
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
                                        color: context.colors.muted,
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
                                  style: TextStyle(color: context.colors.muted),
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
                              itemCount: widget.catalog.topics.length + 1,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: DevmateSpacing.md,
                                    crossAxisSpacing: DevmateSpacing.md,
                                    mainAxisExtent:
                                        146 *
                                        MediaQuery.textScalerOf(context)
                                            .scale(1)
                                            .clamp(1, 2),
                                  ),
                              itemBuilder: (context, index) {
                                if (index == widget.catalog.topics.length) {
                                  return _AddTopicTile(onTap: _addTopic);
                                }
                                final topic = widget.catalog.topics[index];
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

  Future<void> _addTopic() async {
    final topic = await showDevmateForm<InterviewTopic>(
      context: context,
      title: context.l10n.createAddTopic,
      builder: (_) => _NewTopicForm(catalog: widget.catalog),
    );
    if (!mounted || topic == null) return;
    unawaited(context.push('/topic/${topic.id}/edit'));
  }

  void _continue(BuildContext context) {
    for (final topic in widget.catalog.topics) {
      final next = topic.questions.indexWhere(
        (question) => widget.viewModel.scoreFor(question) == null,
      );
      if (next >= 0) {
        context.push('/topic/${topic.id}/practice/$next');
        return;
      }
    }
    for (final topic in widget.catalog.topics) {
      if (topic.questions.isNotEmpty) {
        context.push('/topic/${topic.id}/practice/0');
        return;
      }
    }
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({
    required this.onOpenSettings,
    required this.onOpenSearch,
  });
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSearch;

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
      IconButton(
        tooltip: context.l10n.searchTitle,
        onPressed: onOpenSearch,
        icon: Icon(Icons.search_rounded, size: 23, color: context.colors.muted),
      ),
      IconButton(
        tooltip: context.l10n.settingsTitle,
        onPressed: onOpenSettings,
        icon: Icon(
          Icons.settings_rounded,
          size: 21,
          color: context.colors.muted,
        ),
      ),
    ],
  );
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onStart});
  final VoidCallback? onStart;

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
        style: TextStyle(
          color: context.colors.muted,
          fontSize: 15,
          height: 1.5,
        ),
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
      color: context.colors.surface,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(context.l10n.statsEyebrow, color: context.colors.muted),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
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
                        style: TextStyle(
                          color: context.colors.muted,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Icon(Icons.bolt_rounded, color: context.colors.accent),
            Text(
              '$points XP',
              style: TextStyle(
                color: context.colors.accent,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ProgressTrack(value: total == 0 ? 0 : completed / total),
        const SizedBox(height: 10),
        Text(
          context.l10n.statsCompletedLabel,
          style: TextStyle(color: context.colors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _FreeChatCard extends StatelessWidget {
  const _FreeChatCard();

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: DevmateRadii.cardBorder,
      side: BorderSide(color: context.colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: DevmatePressable(
      borderRadius: DevmateRadii.cardBorder,
      onTap: () => context.push('/chat/free'),
      child: Padding(
        padding: const EdgeInsets.all(DevmateSpacing.xl + 2),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colors.accent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                color: context.colors.accentInk,
                size: 24,
              ),
            ),
            const SizedBox(width: DevmateSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.freeChatTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: DevmateSpacing.xs),
                  Text(
                    context.l10n.freeChatCardSubtitle,
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.muted),
          ],
        ),
      ),
    ),
  );
}

class _CreateTopicCard extends StatelessWidget {
  const _CreateTopicCard();

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: DevmateRadii.cardBorder,
      side: BorderSide(color: context.colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: DevmatePressable(
      borderRadius: DevmateRadii.cardBorder,
      onTap: () => context.push('/chat/create'),
      child: Padding(
        padding: const EdgeInsets.all(DevmateSpacing.xl + 2),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.colors.lavender,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: context.colors.accentInk,
                size: 24,
              ),
            ),
            const SizedBox(width: DevmateSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.createChatTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: DevmateSpacing.xs),
                  Text(
                    context.l10n.createChatCardSubtitle,
                    style: TextStyle(
                      color: context.colors.muted,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.muted),
          ],
        ),
      ),
    ),
  );
}

class _AddTopicTile extends StatelessWidget {
  const _AddTopicTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: DevmateRadii.cardBorder,
      side: BorderSide(color: context.colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: DevmatePressable(
      borderRadius: DevmateRadii.cardBorder,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DevmateSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: context.colors.accent,
            ),
            const Spacer(),
            Text(
              context.l10n.createAddTopic,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Spacer(),
            Icon(Icons.arrow_outward_rounded, color: context.colors.muted),
          ],
        ),
      ),
    ),
  );
}

class _NewTopicForm extends StatefulWidget {
  const _NewTopicForm({required this.catalog});

  final TopicCatalog catalog;

  @override
  State<_NewTopicForm> createState() => _NewTopicFormState();
}

class _NewTopicFormState extends State<_NewTopicForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = context.l10n.addTopicTitleRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final topic = await widget.catalog.addUserTopic(
        _title.text,
        _description.text,
        [],
      );
      if (mounted) Navigator.pop(context, topic);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.l10n.createSaveError;
        });
      }
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
          controller: _title,
          autofocus: true,
          enabled: !_saving,
          textInputAction: TextInputAction.next,
          style: TextStyle(color: context.colors.primary),
          decoration: devmateFieldDecoration(
            context,
            label: l10n.editTopicNameLabel,
          ),
        ),
        const SizedBox(height: DevmateSpacing.md),
        TextField(
          controller: _description,
          enabled: !_saving,
          maxLines: 2,
          style: TextStyle(color: context.colors.primary),
          decoration: devmateFieldDecoration(
            context,
            label: l10n.editTopicDescLabel,
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
                child: Text(l10n.createAddTopic),
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
            children: [
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: Text(l10n.cancelAction),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.createAddTopic),
              ),
            ],
          ),
      ],
    );
  }
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
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: DevmateRadii.cardBorder,
      side: BorderSide(color: context.colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: DevmatePressable(
      borderRadius: DevmateRadii.cardBorder,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DevmateSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  number.toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Icon(
                  iconForTopic(topic.id),
                  color: completed == topic.questions.length
                      ? context.colors.accent
                      : context.colors.lavender,
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
            const SizedBox(height: DevmateSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: ProgressTrack(
                    value: topic.questions.isEmpty
                        ? 0
                        : completed / topic.questions.length,
                  ),
                ),
                const SizedBox(width: DevmateSpacing.lg),
                Text(
                  '$completed/${topic.questions.length}',
                  style: TextStyle(
                    color: context.colors.muted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: DevmateSpacing.xs),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 15,
                  color: context.colors.muted,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
