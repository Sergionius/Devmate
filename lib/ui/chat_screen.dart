import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../data/topic_draft.dart';
import '../l10n/l10n.dart';
import 'chat_view_model.dart';
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
  final String intro;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  late final ChatViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // Логика чата живёт во ViewModel — как раньше тут жил провайдер.
    _viewModel = ChatViewModel(
      settingsRepository: widget.settingsRepository,
      systemPrompt: widget.systemPrompt,
      catalog: widget.catalog,
      appendToTopic: widget.appendToTopic,
      editQuestionId: widget.editQuestionId,
    )..loadSettings();
  }

  Future<void> _openSettings() async {
    await context.push('/settings');
    if (!mounted) return;
    await _viewModel.reloadSettings();
  }

  /// Точка входа для отправки из поля, кнопки и suggestions. Прежняя
  /// семантика: поле очищается только когда сообщение реально ушло
  /// (пустой текст, стрим или отсутствие сессии — не трогают поле).
  void _sendFromInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _viewModel.streaming || _viewModel.session == null) {
      return;
    }
    _input.clear();
    _viewModel.send(trimmed);
  }

  /// Enter (аппаратная клавиатура: десктоп, web, симулятор iOS): не новая
  /// строка, а отправка сообщения и скрытие клавиатуры. Shift+Enter —
  /// перенос строки. Событие перехватывается до Shortcuts — иначе
  /// многострочное поле вставило бы '\n'.
  KeyEventResult _inputKeyHandler(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isEnter =
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    // Незавершённая композиция IME (китайский/японский ввод): Enter
    // подтверждает состав — не отправляем сообщение.
    if (_input.value.composing != TextRange.empty) {
      return KeyEventResult.ignored;
    }
    _sendFromInput(_input.text);
    _inputFocus.unfocus();
    return KeyEventResult.handled;
  }

  Future<void> _applyDraft() async {
    final outcome = await _viewModel.applyDraft();
    if (outcome == null || !mounted) return;
    _showOutcomeSnackBar(outcome);
  }

  Future<void> _replaceAnswer() async {
    final outcome = await _viewModel.replaceAnswer();
    if (outcome == null || !mounted) return;
    _showOutcomeSnackBar(outcome);
  }

  void _showOutcomeSnackBar(ChatSaveOutcome outcome) {
    final message = switch (outcome) {
      ChatSaveOutcome.contentAdded =>
        widget.appendToTopic == null
            ? context.l10n.createAddTopicSuccess
            : context.l10n.appendAddedSuccess(_viewModel.appendTopicTitle!),
      ChatSaveOutcome.answerReplaced => context.l10n.answerReplaced,
      ChatSaveOutcome.saveFailed => context.l10n.createSaveError,
    };
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    body: ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => switch (_viewModel.settingsPhase) {
        ChatSettingsPhase.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        ChatSettingsPhase.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.chatSettingsReadError('${_viewModel.settingsError}'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        ChatSettingsPhase.ready => _buildChat(),
      },
    ),
  );

  Widget _buildChat() {
    final settings = _viewModel.settings!;
    if (!settings.isConfigured) return _buildNotConfigured();
    _viewModel.ensureSession();
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: _viewModel.messages.isEmpty
                ? _buildEmpty()
                : _buildMessages(),
          ),
          if (_viewModel.answerUpdate != null && widget.editQuestionId != null)
            _AnswerUpdateCard(
              update: _viewModel.answerUpdate!,
              onApply: _replaceAnswer,
            ),
          if (_viewModel.draft != null && widget.catalog != null)
            _TopicDraftCard(
              draft: _viewModel.draft!,
              saving: _viewModel.draftSaving,
              appendTitle: widget.appendToTopic == null
                  ? null
                  : _viewModel.appendTopicTitle,
              onAdd: _applyDraft,
            ),
          _buildInput(),
        ],
      ),
    );
  }

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
            onTap: () => _sendFromInput(suggestion),
            enabled: !_viewModel.streaming,
          ),
          const SizedBox(height: 12),
        ],
      ],
    ],
  );

  Widget _buildMessages() {
    final messages = _viewModel.messages;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[messages.length - 1 - index];
        final isLast = index == 0;
        final session = _viewModel.session;
        if (!isLast || session == null) {
          return _Bubble(message: message, streaming: false);
        }
        // Последний ответ слушает сессию напрямую: на каждый чанк
        // перестраивается только этот пузырь, не весь список.
        return AnimatedBuilder(
          animation: session,
          builder: (context, _) =>
              _Bubble(message: message, streaming: _viewModel.streaming),
        );
      },
    );
  }

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
              child: Focus(
                onKeyEvent: _inputKeyHandler,
                child: TextField(
                  controller: _input,
                  focusNode: _inputFocus,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (text) {
                    // Enter/«Отправить» на мягкой клавиатуре: не оставляем
                    // клавиатуру раскрытой после отправки.
                    _inputFocus.unfocus();
                    _sendFromInput(text);
                  },
                  enabled: !_viewModel.streaming,
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
        ),
        const SizedBox(width: 10),
        _SendButton(
          onPressed: () => _sendFromInput(_input.text),
          enabled: !_viewModel.streaming,
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    _viewModel.dispose();
    super.dispose();
  }
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
    // Текст ошибки не вшивается в сообщение, а вычисляется при рендере:
    // история сессии остаётся чистой для повторных запросов. К сырой ошибке
    // провайдера добавляем его собственный ответ (лимиты подписки и т.п.).
    final errorKind = message.errorKind;
    final errorText = errorKind == null
        ? null
        : context.llmErrorText(errorKind);
    final detail = message.errorDetail?.trim();
    final detailSuffix = detail == null || detail.isEmpty
        ? ''
        : '\n\n${context.l10n.llmProviderDetail(detail)}';
    final text = errorText == null
        ? message.text
        : message.text.isEmpty
        ? '$errorText$detailSuffix'
        // Стрим оборвался после частичного ответа: показываем и его,
        // и причину обрыва.
        : '${message.text}\n\n$errorText$detailSuffix';
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
