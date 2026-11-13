import 'package:flutter/material.dart';

import '../domain/question.dart';
import 'design_system.dart';
import 'training_view_model.dart';

enum _Stage { answer, compare, rewrite, finished }

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({
    super.key,
    required this.topic,
    required this.initialIndex,
    required this.viewModel,
  });
  final InterviewTopic topic;
  final int initialIndex;
  final TrainingViewModel viewModel;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.viewModel.error ?? 'Не удалось сохранить ответ'),
        ),
      );
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
    appBar: AppBar(title: Text(widget.topic.title)),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
          children: [
            Row(
              children: [
                Expanded(
                  child: Eyebrow(
                    'ВОПРОС ${_index + 1} / ${widget.topic.questions.length}',
                  ),
                ),
                const Icon(
                  Icons.bolt_rounded,
                  color: DevmateColors.accent,
                  size: 19,
                ),
                Text(
                  '${widget.viewModel.points} XP',
                  style: const TextStyle(
                    color: DevmateColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ProgressTrack(value: (_index + 1) / widget.topic.questions.length),
            const SizedBox(height: 40),
            Text(
              _question.prompt,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontSize: 28, height: 1.22),
            ),
            const SizedBox(height: 28),
            if (_stage == _Stage.answer) ...[
              const Eyebrow('01 / ТВОЙ ОТВЕТ', color: DevmateColors.muted),
              const SizedBox(height: 10),
              const Text(
                'Сформулируй своими словами. Здесь нет автоматической проверки — сначала попробуй вспомнить сам.',
                style: TextStyle(color: DevmateColors.muted, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('answer-field'),
                controller: _answer,
                maxLines: 6,
                minLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Твой ответ',
                  alignLabelWithHint: true,
                  hintText: 'Начни писать здесь...',
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
                child: const Text('Сверить с эталоном'),
              ),
            ] else if (_stage == _Stage.compare) ...[
              const Eyebrow('02 / СРАВНЕНИЕ', color: DevmateColors.muted),
              const SizedBox(height: 16),
              _AnswerCard(label: 'ТВОЙ ОТВЕТ', text: _answer.text),
              const SizedBox(height: 12),
              _AnswerCard(
                label: 'ЭТАЛОННЫЙ ОТВЕТ',
                text: _question.answer,
                highlight: true,
              ),
              const SizedBox(height: 26),
              Text(
                'Насколько близко получилось?',
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
                        label: const Text('Знал ответ · +10 XP'),
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
                        label: const Text('Нужно повторить'),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_stage == _Stage.rewrite) ...[
              const Eyebrow('03 / ЗАКРЕПЛЕНИЕ'),
              const SizedBox(height: 12),
              const Text(
                'Вспомни эталонный ответ и запиши его снова своими словами. Мы не сравниваем формулировки автоматически.',
                style: TextStyle(color: DevmateColors.muted, height: 1.5),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('rewrite-field'),
                controller: _rewrite,
                maxLines: 6,
                minLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Что важно запомнить?',
                  alignLabelWithHint: true,
                  hintText: 'Запиши суть ответа...',
                ),
              ),
              const SizedBox(height: 20),
              ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) => FilledButton(
                  onPressed: _hasRewrite && !widget.viewModel.saving
                      ? () => _finish(false)
                      : null,
                  child: const Text('Закрепить · +5 XP'),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() => _stage = _Stage.compare);
                  _scrollToTop();
                },
                child: const Text('Посмотреть эталон снова'),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: DevmateColors.surface,
                  border: Border.all(color: DevmateColors.border),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 40,
                      color: DevmateColors.accent,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _knewAnswer
                          ? 'Отлично. Ответ засчитан.'
                          : 'Сложное становится понятнее.',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Прогресс сохранён на этом устройстве.',
                      style: TextStyle(color: DevmateColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _next,
                child: Text(
                  _index + 1 == widget.topic.questions.length
                      ? 'К теме'
                      : 'Следующий вопрос',
                ),
              ),
            ],
          ],
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
      color: highlight ? DevmateColors.surfaceRaised : DevmateColors.surface,
      border: Border.all(
        color: highlight
            ? DevmateColors.accent.withValues(alpha: 0.55)
            : DevmateColors.border,
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(
          label,
          color: highlight ? DevmateColors.accent : DevmateColors.muted,
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
