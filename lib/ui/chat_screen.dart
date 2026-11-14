import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../data/topic_draft.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.title,
    required this.systemPrompt,
    required this.settingsRepository,
    required this.intro,
    this.suggestions = const [],
    this.catalog,
    this.appendToTopic,
    this.editQuestionId,
  });

  final String title;
  final String systemPrompt;
  final String intro;
  final LlmSettingsRepository settingsRepository;

  /// Задан только в чатах работы с темами: после ответа модели код ищет
  /// JSON-черновик и показывает карточку с действием.
  final TopicCatalog? catalog;

  /// Если задан — черновик воспринимается как вопросы для этой темы
  /// (без поля title), а кнопка добавляет их в неё.
  final String? appendToTopic;

  /// Если задан — ответы модели в этом чате могут заменять ответ этого
  /// вопроса (JSON action=update_answer).
  final String? editQuestionId;
  final List<String> suggestions;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Future<LlmSettings> _settingsFuture;
  OpenAiCompatibleProvider? _provider;
  final List<LlmChatMessage> _messages = [];
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  bool _streaming = false;
  TopicDraft? _draft;
  AnswerUpdate? _answerUpdate;
  bool _draftSaving = false;

  @override
  void initState() {
    super.initState();
    _settingsFuture = widget.settingsRepository.load();
  }

  Future<void> _openSettings() async {
    await context.push('/settings');
    if (!mounted) return;
    setState(() {
      _provider = null;
      _messages.clear();
      _settingsFuture = widget.settingsRepository.load();
    });
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _streaming || _provider == null) return;
    setState(() {
      _messages
        ..add(LlmChatMessage(LlmRole.user, text))
        ..add(LlmChatMessage(LlmRole.assistant, ''));
      _input.clear();
      _streaming = true;
    });
    try {
      await for (final chunk in _provider!.sendMessageStream(text)) {
        if (!mounted) return;
        setState(() => _messages.last.text += chunk);
      }
      // Провайдер не отдаёт ошибку чанком: локализуем её по errorKind.
      final failureKind = _provider!.history.last.errorKind;
      if (failureKind != null && mounted) {
        setState(() {
          final last = _messages.last;
          last.text = last.text.isEmpty
              ? context.llmErrorText(failureKind)
              : '${last.text}\n\n${context.llmErrorText(failureKind)}';
        });
      }
      // В чатах работы с темами ищем JSON в ответе модели.
      final catalog = widget.catalog;
      final isQuestionEdit = widget.editQuestionId != null;
      if (catalog == null || !mounted) return;

      final update = isQuestionEdit
          ? parseAnswerUpdate(_provider!.history.last.text)
          : null;
      if (update != null) {
        setState(() {
          _answerUpdate = update;
          _draft = null;
        });
        return;
      }
      if (isQuestionEdit) return;

      final draft = parseTopicDraft(_provider!.history.last.text);
      if (draft == null) {
        // Уточняющий ответ: убираем карточку от прошлого хода, если была.
        if (_draft != null) setState(() => _draft = null);
        return;
      }
      final isAppend = widget.appendToTopic != null;
      if (isAppend || draft.title != null) {
        setState(() => _draft = draft);
      }
    } finally {
      if (mounted) setState(() => _streaming = false);
    }
  }

  Future<void> _applyDraft(TopicCatalog catalog) async {
    final draft = _draft;
    final appendTo = widget.appendToTopic;
    if (draft == null || _draftSaving) return;
    setState(() => _draftSaving = true);
    final l10n = context.l10n;
    final String success;
    try {
      if (appendTo != null) {
        final title = _topicTitle(context);
        await catalog.addQuestionsToTopic(appendTo, draft.questions);
        success = l10n.appendAddedSuccess(title);
      } else {
        await catalog.addUserTopic(
          draft.title!,
          draft.description ?? '',
          draft.questions,
        );
        success = l10n.createAddTopicSuccess;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _draftSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.createSaveError)));
      }
      return;
    }
    _draftSaving = false;
    if (!mounted) return;
    setState(() {
      _draft = null;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(success)));
  }

  Future<void> _replaceAnswer(String questionId) async {
    final update = _answerUpdate;
    if (update == null) return;
    final catalog = widget.catalog!;
    final l10n = context.l10n;
    try {
      await catalog.updateQuestion(questionId, update.prompt, update.answer);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.createSaveError)));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _answerUpdate = null);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.answerReplaced)));
  }

  String _topicTitle(BuildContext context) =>
      widget.catalog?.topicById(widget.appendToTopic!)?.title ??
      widget.appendToTopic!;

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _provider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title, overflow: TextOverflow.ellipsis),
      automaticallyImplyLeading: !kIsWeb,
      actions: [
        IconButton(
          tooltip: context.l10n.aiSettings,
          onPressed: _openSettings,
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    ),
    body: FutureBuilder<LlmSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.chatSettingsReadError('${snapshot.error}'),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final settings = snapshot.data!;
        if (!settings.isConfigured) return _buildNotConfigured();
        _provider ??= OpenAiCompatibleProvider(
          settings: settings,
          systemPrompt: widget.systemPrompt,
        );
        return SafeArea(
          top: false,
          child: Column(
            children: [
              Expanded(child: _messages.isEmpty ? _buildEmpty() : _buildList()),
              if (_answerUpdate != null && widget.editQuestionId != null)
                _AnswerUpdateCard(
                  update: _answerUpdate!,
                  onApply: () => _replaceAnswer(widget.editQuestionId!),
                ),
              if (_draft != null && widget.catalog != null)
                _TopicDraftCard(
                  draft: _draft!,
                  saving: _draftSaving,
                  appendTitle: widget.appendToTopic == null
                      ? null
                      : _topicTitle(context),
                  onAdd: () => _applyDraft(widget.catalog!),
                ),
              _buildInput(),
            ],
          ),
        );
      },
    ),
  );

  Widget _buildNotConfigured() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.key_rounded,
            size: 44,
            color: DevmateColors.lavender,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.chatKeyRequired,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.chatKeyRequiredDescription,
            textAlign: TextAlign.center,
            style: TextStyle(color: DevmateColors.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded),
            label: Text(context.l10n.openSettings),
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
    children: [
      Eyebrow(context.l10n.chatEyebrow, color: DevmateColors.muted),
      const SizedBox(height: 12),
      Text(widget.intro, style: const TextStyle(fontSize: 18, height: 1.45)),
      if (widget.suggestions.isNotEmpty) ...[
        const SizedBox(height: 24),
        for (final suggestion in widget.suggestions) ...[
          _SuggestionCard(
            text: suggestion,
            onTap: () => _send(suggestion),
            enabled: !_streaming,
          ),
          const SizedBox(height: 12),
        ],
      ],
    ],
  );

  Widget _buildList() => ListView.builder(
    reverse: true,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    itemCount: _messages.length,
    itemBuilder: (context, index) {
      final message = _messages[_messages.length - 1 - index];
      final isLast = index == 0;
      return _Bubble(message: message, streaming: isLast && _streaming);
    },
  );

  Widget _buildInput() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                color: DevmateColors.surface,
                border: Border.all(color: DevmateColors.border),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _input,
                focusNode: _inputFocus,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                enabled: !_streaming,
                style: const TextStyle(
                  color: DevmateColors.primary,
                  fontSize: 16,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.chatInputHint,
                  hintStyle: const TextStyle(color: DevmateColors.muted),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _SendButton(onPressed: () => _send(_input.text), enabled: !_streaming),
      ],
    ),
  );
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.text,
    required this.onTap,
    required this.enabled,
  });

  final String text;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Material(
    color: DevmateColors.surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: DevmateColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
      ),
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.streaming});

  final LlmChatMessage message;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == LlmRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.82 : 0.94),
        ),
        decoration: BoxDecoration(
          color: isUser ? DevmateColors.accent : DevmateColors.surface,
          border: isUser ? null : Border.all(color: DevmateColors.border),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: isUser
            ? Text(
                message.text,
                style: const TextStyle(
                  color: DevmateColors.accentInk,
                  fontSize: 15.5,
                  height: 1.45,
                ),
              )
            : _assistantBody(context),
      ),
    );
  }

  Widget _assistantBody(BuildContext context) {
    final text = message.text;
    if (text.isEmpty && streaming) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    final markdown = MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: const TextStyle(
        color: DevmateColors.primary,
        fontSize: 15.5,
        height: 1.5,
      ),
      strong: const TextStyle(
        color: DevmateColors.primary,
        fontSize: 15.5,
        fontWeight: FontWeight.bold,
      ),
      em: const TextStyle(
        color: DevmateColors.primary,
        fontSize: 15.5,
        fontStyle: FontStyle.italic,
      ),
      h1: const TextStyle(
        color: DevmateColors.primary,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      h2: const TextStyle(
        color: DevmateColors.primary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      h3: const TextStyle(
        color: DevmateColors.primary,
        fontSize: 16.5,
        fontWeight: FontWeight.bold,
      ),
      listBullet: const TextStyle(
        color: DevmateColors.primary,
        fontSize: 15.5,
        height: 1.5,
      ),
      code: const TextStyle(
        color: DevmateColors.accent,
        backgroundColor: DevmateColors.canvas,
        fontSize: 14,
      ),
      codeblockDecoration: BoxDecoration(
        color: DevmateColors.canvas,
        border: Border.all(color: DevmateColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: DevmateColors.lavender, width: 3),
        ),
      ),
      a: const TextStyle(color: DevmateColors.lavender),
      blockSpacing: 10,
    );
    return MarkdownBody(
      data: streaming ? '$text ▍' : text,
      styleSheet: markdown,
      softLineBreak: true,
      shrinkWrap: true,
    );
  }
}

class _TopicDraftCard extends StatelessWidget {
  const _TopicDraftCard({
    required this.draft,
    required this.saving,
    required this.onAdd,
    required this.appendTitle,
  });

  final TopicDraft draft;
  final bool saving;
  final VoidCallback onAdd;

  /// Название существующей темы в append-режиме; null — создание новой.
  final String? appendTitle;

  @override
  Widget build(BuildContext context) {
    final appendTitle = this.appendTitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DevmateColors.surface,
          border: Border.all(color: DevmateColors.accent),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appendTitle ?? (draft.title ?? ''),
              style: const TextStyle(
                color: DevmateColors.primary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (appendTitle == null &&
                (draft.description?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                draft.description!,
                style: const TextStyle(
                  color: DevmateColors.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${draft.questions.length} ${context.l10n.createAddedQuestionsSuffix(draft.questions.length)}',
              style: const TextStyle(
                color: DevmateColors.lavender,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: saving ? null : onAdd,
                icon: const Icon(Icons.library_add_rounded),
                label: Text(
                  appendTitle == null
                      ? context.l10n.createAddTopic
                      : context.l10n.appendAddTopic(appendTitle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerUpdateCard extends StatelessWidget {
  const _AnswerUpdateCard({required this.update, required this.onApply});

  final AnswerUpdate update;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DevmateColors.surface,
        border: Border.all(color: DevmateColors.accent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.answerUpdateCardTitle,
            style: const TextStyle(
              color: DevmateColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (update.prompt.isNotEmpty) ...[
            Text(
              context.l10n.answerUpdatePromptLabel,
              style: const TextStyle(color: DevmateColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              update.prompt,
              style: const TextStyle(
                color: DevmateColors.primary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            context.l10n.editAnswerLabel,
            style: const TextStyle(color: DevmateColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            update.answer,
            style: const TextStyle(
              color: DevmateColors.primary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.check_rounded),
              label: Text(context.l10n.answerUpdateButton),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed, required this.enabled});

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: Material(
      color: enabled ? DevmateColors.accent : DevmateColors.surface,
      shape: CircleBorder(
        side: BorderSide(
          color: enabled ? DevmateColors.accent : DevmateColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        child: Icon(
          Icons.arrow_upward_rounded,
          size: 24,
          color: enabled ? DevmateColors.accentInk : DevmateColors.muted,
        ),
      ),
    ),
  );
}
