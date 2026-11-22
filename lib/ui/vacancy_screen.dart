import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';
import 'vacancy_view_model.dart';

class VacancyScreen extends StatefulWidget {
  const VacancyScreen({
    super.key,
    required this.catalog,
    required this.settings,
    this.aiDisabled,
    this.sessionFactory,
  });

  final TopicCatalog catalog;
  final LlmSettingsRepository settings;
  final ValueListenable<bool>? aiDisabled;
  final ChatSession Function(LlmSettings, String)? sessionFactory;

  @override
  State<VacancyScreen> createState() => _VacancyScreenState();
}

class _VacancyScreenState extends State<VacancyScreen> {
  final _vacancy = TextEditingController();
  final _title = TextEditingController();
  final _description = TextEditingController();
  late final VacancyViewModel _model = VacancyViewModel(
    settings: widget.settings,
    catalog: widget.catalog,
    sessionFactory: widget.sessionFactory,
  );
  String _topicId = '';

  @override
  void initState() {
    super.initState();
    widget.aiDisabled?.addListener(_onAiDisabled);
  }

  void _onAiDisabled() {
    if ((widget.aiDisabled?.value ?? false) &&
        _model.phase == VacancyPhase.generating) {
      _model.cancelGeneration();
    }
  }

  Future<void> _generate() async {
    if (widget.aiDisabled?.value ?? false) return;
    if (_vacancy.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.vacancyEnterText)));
      return;
    }
    if (_model.phase == VacancyPhase.preview) {
      final replace = await showDevmateConfirm(
        context,
        title: context.l10n.vacancyReplaceTitle,
        message: context.l10n.vacancyReplaceWarning,
        confirmLabel: context.l10n.vacancyReplaceAction,
        cancelLabel: context.l10n.cancelAction,
        destructive: true,
      );
      if (replace != true || !mounted || (widget.aiDisabled?.value ?? false)) {
        return;
      }
    }
    await _model.generate(_vacancy.text, context.l10n.vacancyInstruction);
    if (!mounted) return;
    if (_model.draft != null) {
      _title.text = _model.draft!.title ?? '';
      _description.text = _model.draft!.description ?? '';
    }
  }

  Future<void> _chooseTopic() async {
    FocusScope.of(context).unfocus();
    final chosen = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoTheme(
        data: CupertinoThemeData(
          brightness: Theme.of(sheetContext).brightness,
          primaryColor: context.colors.accent,
          scaffoldBackgroundColor: context.colors.canvas,
          barBackgroundColor: context.colors.surfaceRaised,
        ),
        child: CupertinoActionSheet(
          title: Text(context.l10n.vacancyDestination),
          actions: [
            for (final (id, title) in [
              ('', context.l10n.vacancyNewTopic),
              for (final topic in widget.catalog.topics)
                (topic.id, topic.title),
            ])
              CupertinoActionSheetAction(
                onPressed: () => Navigator.pop(sheetContext, id),
                child: Semantics(
                  selected: _topicId == id,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text(title)),
                      if (_topicId == id) ...[
                        const SizedBox(width: 8),
                        const Icon(CupertinoIcons.check_mark, size: 18),
                      ],
                    ],
                  ),
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(context.l10n.cancelAction),
          ),
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => _topicId = chosen);
  }

  Future<void> _save() async {
    if (widget.aiDisabled?.value ?? false) return;
    final saved = await _model.save(
      topicId: _topicId.isEmpty ? null : _topicId,
      title: _title.text,
      description: _description.text,
    );
    if (!mounted) return;
    if (saved) {
      context.pop();
    } else if (_model.error == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.vacancyValidate)));
    }
  }

  Future<void> _edit(int index) async {
    final current = _model.questions[index];
    final edited = await showDevmateForm<(String, String)>(
      context: context,
      title: context.l10n.vacancyEdit,
      builder: (formContext) =>
          _VacancyQuestionEditor(prompt: current.$1, answer: current.$2),
    );
    if (mounted && edited != null && index < _model.questions.length) {
      _model.updateQuestion(index, edited.$1, edited.$2);
    }
  }

  @override
  void dispose() {
    widget.aiDisabled?.removeListener(_onAiDisabled);
    _model.dispose();
    _vacancy.dispose();
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.vacancyTitle)),
    body: ListenableBuilder(
      listenable: Listenable.merge([_model, widget.catalog, widget.aiDisabled]),
      builder: (context, _) {
        if (widget.aiDisabled?.value ?? false) {
          return Center(child: Text(context.l10n.vacancyAiDisabled));
        }
        final busy =
            _model.phase == VacancyPhase.generating ||
            _model.phase == VacancyPhase.saving;
        final preview =
            _model.phase == VacancyPhase.preview ||
            _model.phase == VacancyPhase.saving;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                Text(context.l10n.vacancyIntro),
                const SizedBox(height: 16),
                TextField(
                  controller: _vacancy,
                  minLines: 1,
                  maxLines: 12,
                  keyboardType: TextInputType.multiline,
                  enabled: !busy,
                  decoration: devmateFieldDecoration(
                    context,
                    label: context.l10n.vacancyText,
                    hint: context.l10n.vacancyHint,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: busy ? null : _generate,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(context.l10n.vacancyGenerate),
                ),
                if (busy) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DevmateDotsLoader(dotSize: 7),
                        const SizedBox(height: 10),
                        Text(
                          context.l10n.vacancyGenerating,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
                if (_model.error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    switch (_model.error!) {
                      VacancyFailure.notConfigured =>
                        context.l10n.vacancyKeyRequired,
                      VacancyFailure.generation =>
                        context.l10n.vacancyGenerationError,
                      VacancyFailure.invalidReply =>
                        context.l10n.vacancyInvalidReply,
                      VacancyFailure.save => context.l10n.vacancySaveError,
                    },
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  if (_model.error == VacancyFailure.notConfigured)
                    TextButton(
                      onPressed: () => context.push('/settings/ai'),
                      child: Text(context.l10n.aiSettings),
                    ),
                ],
                if (preview) ...[
                  const SizedBox(height: 28),
                  Text(
                    context.l10n.vacancyPreview,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (!kIsWeb &&
                      Theme.of(context).platform == TargetPlatform.iOS)
                    DevmateSelectionField(
                      label: context.l10n.vacancyDestination,
                      value: _topicId.isEmpty
                          ? context.l10n.vacancyNewTopic
                          : (widget.catalog.topicById(_topicId)?.title ??
                                context.l10n.vacancyNewTopic),
                      onPressed: busy ? null : _chooseTopic,
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _topicId,
                      decoration: InputDecoration(
                        labelText: context.l10n.vacancyDestination,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: '',
                          child: Text(context.l10n.vacancyNewTopic),
                        ),
                        for (final topic in widget.catalog.topics)
                          DropdownMenuItem(
                            value: topic.id,
                            child: Text(
                              topic.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (id) => setState(() => _topicId = id ?? ''),
                    ),
                  if (_topicId.isEmpty) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _title,
                      enabled: !busy,
                      decoration: devmateFieldDecoration(
                        context,
                        label: context.l10n.vacancyTopicTitle,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _description,
                      enabled: !busy,
                      minLines: 1,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      decoration: devmateFieldDecoration(
                        context,
                        label: context.l10n.vacancyTopicDescription,
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_model.questions.isEmpty)
                    Text(context.l10n.vacancyNoQuestions),
                  for (var i = 0; i < _model.questions.length; i++)
                    Card(
                      margin: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                      child: ListTile(
                        title: Text(_model.questions[i].$1),
                        subtitle: Text(
                          _model.questions[i].$2,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: busy ? null : () => _edit(i),
                        trailing: IconButton(
                          tooltip: context.l10n.vacancyRemove,
                          onPressed: busy
                              ? null
                              : () => _model.removeQuestion(i),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: busy || _model.questions.isEmpty ? null : _save,
                    icon: const Icon(Icons.library_add_rounded),
                    label: Text(context.l10n.vacancySave),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _VacancyQuestionEditor extends StatefulWidget {
  const _VacancyQuestionEditor({required this.prompt, required this.answer});

  final String prompt;
  final String answer;

  @override
  State<_VacancyQuestionEditor> createState() => _VacancyQuestionEditorState();
}

class _VacancyQuestionEditorState extends State<_VacancyQuestionEditor> {
  late final _prompt = TextEditingController(text: widget.prompt);
  late final _answer = TextEditingController(text: widget.answer);
  bool _invalid = false;

  @override
  void dispose() {
    _prompt.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _updateValidation() {
    if (_invalid &&
        _prompt.text.trim().isNotEmpty &&
        _answer.text.trim().isNotEmpty) {
      setState(() => _invalid = false);
    }
  }

  void _apply() {
    final prompt = _prompt.text.trim();
    final answer = _answer.text.trim();
    if (prompt.isEmpty || answer.isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    Navigator.pop(context, (prompt, answer));
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: _prompt,
        onChanged: (_) => _updateValidation(),
        minLines: 1,
        maxLines: 3,
        decoration: devmateFieldDecoration(
          context,
          label: context.l10n.vacancyQuestion,
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _answer,
        onChanged: (_) => _updateValidation(),
        minLines: 1,
        maxLines: 6,
        decoration: devmateFieldDecoration(
          context,
          label: context.l10n.vacancyAnswer,
          alignLabelWithHint: true,
        ),
      ),
      if (_invalid) ...[
        const SizedBox(height: 8),
        Text(
          context.l10n.vacancyValidate,
          style: TextStyle(color: context.colors.error),
        ),
      ],
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancelAction),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _apply,
              child: Text(context.l10n.vacancyApply),
            ),
          ),
        ],
      ),
    ],
  );
}
