import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/question.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';
import 'training_view_model.dart';

enum _Stage { answer, compare, rewrite, finished }

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.topic,
    required this.initialIndex,
    required this.viewModel,
    this.aiDisabled,
  });
  final InterviewTopic topic;
  final int initialIndex;
  final TrainingViewModel viewModel;

  final ValueListenable<bool>? aiDisabled;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late int _index = widget.initialIndex;
  final _answer = TextEditingController();
  final _rewrite = TextEditingController();
  final _scroll = ScrollController();
  _Stage _stage = _Stage.answer;
  bool _hasAnswer = false;
  bool _hasRewrite = false;
  bool _knewAnswer = false;

  InterviewQuestion get _question => widget.topic.questions[_index];

  @override
  void initState() {
    super.initState();
    _answer.addListener(_onAnswerChanged);
    _rewrite.addListener(_onRewriteChanged);
  }

  void _onAnswerChanged() =>
      setState(() => _hasAnswer = _answer.text.trim().isNotEmpty);
  void _onRewriteChanged() =>
      setState(() => _hasRewrite = _rewrite.text.trim().isNotEmpty);

  @override
  void dispose() {
    _answer.dispose();
    _rewrite.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _finish(bool knewAnswer) async {
    final saved = await widget.viewModel.record(
      _question,
      knewAnswer: knewAnswer,
    );
    if (!mounted) return;
    if (saved) {
      setState(() {
        _knewAnswer = knewAnswer;
        _stage = _Stage.finished;
      });
      _scrollToTop();
    } else {
      showDevmateNotice(context, switch (widget.viewModel.error) {
        TrainingError.progressLoad => context.l10n.progressLoadError,
        TrainingError.answerSave => context.l10n.answerSaveError,
        null => context.l10n.practiceSaveFailed,
      }, kind: DevmateNoticeKind.error);
    }
  }

  void _scrollToTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _next() {
    if (_index + 1 == widget.topic.questions.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _index++;
      _stage = _Stage.answer;
      _answer.clear();
      _rewrite.clear();
    });
    _scrollToTop();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.topic.title),

      automaticallyImplyLeading: !kIsWeb,
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Scrollbar(
          controller: _scroll,
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Eyebrow(
                      context.l10n.questionProgress(
                        _index + 1,
                        widget.topic.questions.length,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.bolt_rounded,
                    color: context.colors.accent,
                    size: 19,
                  ),
                  Text(
                    '${widget.viewModel.points} XP',
                    style: TextStyle(
                      color: context.colors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ProgressTrack(
                value: (_index + 1) / widget.topic.questions.length,
              ),
              const SizedBox(height: 40),
              SelectableText(
                _question.prompt,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontSize: 28, height: 1.22),
              ),
              const SizedBox(height: 28),
              if (_stage == _Stage.answer) ...[
                Eyebrow(
                  context.l10n.stepYourAnswer,
                  color: context.colors.muted,
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.yourAnswerHint,
                  style: TextStyle(color: context.colors.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('answer-field'),
                  controller: _answer,
                  maxLines: 6,
                  minLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: devmateFieldDecoration(
                    context,
                    label: context.l10n.yourAnswerLabel,
                    hint: context.l10n.answerPlaceholder,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _hasAnswer
                      ? () {
                          FocusScope.of(context).unfocus();
                          setState(() => _stage = _Stage.compare);
                          _scrollToTop();
                        }
                      : null,
                  child: Text(context.l10n.compareWithReference),
                ),
                const SizedBox(height: 12),
                DevmateAiVisibility(
                  aiDisabled: widget.aiDisabled,
                  topGap: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/chat/question/${widget.topic.id}/$_index',
                      extra: _answer.text.trim(),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: Text(context.l10n.discussWithAi),
                  ),
                ),
              ] else if (_stage == _Stage.compare) ...[
                Eyebrow(
                  context.l10n.stepComparison,
                  color: context.colors.muted,
                ),
                const SizedBox(height: 16),
                _AnswerCard(
                  label: context.l10n.yourAnswerEyebrow,
                  text: _answer.text,
                ),
                const SizedBox(height: 12),
                _AnswerCard(
                  label: context.l10n.referenceAnswerEyebrow,
                  text: _question.answer,
                  highlight: true,
                ),
                const SizedBox(height: 26),
                Text(
                  context.l10n.howCloseQuestion,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, _) => Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: widget.viewModel.saving
                              ? null
                              : () => _finish(true),
                          icon: const Icon(Icons.check_rounded),
                          label: Text(context.l10n.knewAnswerXp),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: widget.viewModel.saving
                              ? null
                              : () {
                                  setState(() => _stage = _Stage.rewrite);
                                  _scrollToTop();
                                },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(context.l10n.needsRepeat),
                        ),
                      ),
                      const SizedBox(height: 10),

                      DevmateAiVisibility(
                        aiDisabled: widget.aiDisabled,
                        topGap: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(
                              '/chat/question/${widget.topic.id}/$_index',
                              extra: _answer.text.trim(),
                            ),
                            icon: const Icon(Icons.chat_rounded, size: 20),
                            label: Text(context.l10n.discussWithAi),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_stage == _Stage.rewrite) ...[
                Eyebrow(context.l10n.stepConsolidation),
                const SizedBox(height: 12),
                Text(
                  context.l10n.consolidationHint,
                  style: TextStyle(color: context.colors.muted, height: 1.5),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('rewrite-field'),
                  controller: _rewrite,
                  maxLines: 6,
                  minLines: 4,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  textCapitalization: TextCapitalization.sentences,
                  decoration: devmateFieldDecoration(
                    context,
                    label: context.l10n.whatToRemember,
                    hint: context.l10n.writeEssencePlaceholder,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, _) => FilledButton(
                    onPressed: _hasRewrite && !widget.viewModel.saving
                        ? () => _finish(false)
                        : null,
                    child: Text(context.l10n.consolidateXp),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => _stage = _Stage.compare);
                    _scrollToTop();
                  },
                  child: Text(context.l10n.viewReferenceAgain),
                ),
                const SizedBox(height: 12),

                DevmateAiVisibility(
                  aiDisabled: widget.aiDisabled,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(
                      '/chat/question/${widget.topic.id}/$_index',
                      extra: _answer.text.trim(),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 20),
                    label: Text(context.l10n.discussWithAi),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    border: Border.all(color: context.colors.border),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 40,
                        color: context.colors.accent,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _knewAnswer
                            ? context.l10n.doneTitle
                            : context.l10n.doneSubtitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.l10n.progressSavedNote,
                        style: TextStyle(color: context.colors.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _next,
                  child: Text(
                    _index + 1 == widget.topic.questions.length
                        ? context.l10n.backToTopic
                        : context.l10n.nextQuestion,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.label,
    required this.text,
    this.highlight = false,
  });
  final String label;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: highlight ? context.colors.surfaceRaised : context.colors.surface,
      border: Border.all(
        color: highlight
            ? context.colors.accent.withValues(alpha: 0.55)
            : context.colors.border,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(
          label,
          color: highlight ? context.colors.accent : context.colors.muted,
        ),
        const SizedBox(height: 12),
        SelectableText(
          text,
          style: const TextStyle(fontSize: 16, height: 1.55),
        ),
      ],
    ),
  );
}
