import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
// flutter_markdown_plus requires Flutter's ThemeData, not material_ui.ThemeData.
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as flutter_material;
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../data/chat_history_repository.dart';
import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../data/topic_catalog.dart';
import '../data/topic_draft.dart';
import '../l10n/l10n.dart';
import 'chat_view_model.dart';
import 'design_system.dart';
import 'platform_ui.dart';
import 'reply_preview.dart';

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
    this.initialQuestion,
    this.initialInput,
    this.sessionFactory,
    this.historyRepository,
    this.chatId,
  });

  final String title;
  final String systemPrompt;
  final LlmSettingsRepository settingsRepository;

  final TopicCatalog? catalog;

  final String? appendToTopic;

  final String? editQuestionId;
  final String? initialQuestion;
  final String? initialInput;
  final List<String> suggestions;
  final String intro;

  final ChatSession Function(LlmSettings settings, String systemPrompt)?
  sessionFactory;
  final ChatHistoryRepository? historyRepository;
  final String? chatId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _messageScroll = ScrollController();
  ChatSession? _observedSession;
  bool _scrollCorrectionScheduled = false;
  late final ChatViewModel _viewModel;
  LlmChatMessage? _questionContext;

  @override
  void initState() {
    super.initState();
    _input.text = widget.initialInput ?? '';
    if (widget.initialQuestion != null) {
      _questionContext = LlmChatMessage(
        LlmRole.assistant,
        widget.initialQuestion!,
      );
    }

    _viewModel = ChatViewModel(
      settingsRepository: widget.settingsRepository,
      systemPrompt: widget.systemPrompt,
      catalog: widget.catalog,
      appendToTopic: widget.appendToTopic,
      editQuestionId: widget.editQuestionId,
      onSessionDetached: _detachObservedSession,
      historyRepository: widget.historyRepository,
      chatId: widget.chatId,
      sessionFactory: widget.sessionFactory,
    )..loadSettings();
  }

  void _detachObservedSession(ChatSession session) {
    if (identical(_observedSession, session)) {
      session.removeListener(_keepReadingPosition);
      _observedSession = null;
    }
  }

  Future<void> _openSettings() async {
    final session = _observedSession;
    if (session != null) _detachObservedSession(session);
    await context.push('/settings/ai');
    if (!mounted) return;
    await _viewModel.reloadSettings();
  }

  void _sendFromInput(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _viewModel.streaming || _viewModel.session == null) {
      return;
    }
    _input.clear();
    _viewModel.send(trimmed).then((_) {
      if (mounted && _viewModel.persistenceError != null) {
        showDevmateNotice(
          context,
          context.l10n.chatHistorySaveError,
          kind: DevmateNoticeKind.error,
        );
      }
    });
  }

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

    if (_input.value.composing != TextRange.empty) {
      return KeyEventResult.ignored;
    }
    _sendFromInput(_input.text);
    _inputFocus.unfocus();
    return KeyEventResult.handled;
  }

  Future<void> _retry() async {
    await _viewModel.retry();
    if (mounted && _viewModel.persistenceError != null) {
      showDevmateNotice(
        context,
        context.l10n.chatHistorySaveError,
        kind: DevmateNoticeKind.error,
      );
    }
  }

  Future<void> _applyDraft() async {
    final outcome = await _viewModel.applyDraft();
    if (outcome == null || !mounted) return;
    _showOutcomeNotice(outcome);
  }

  Future<void> _replaceAnswer() async {
    final outcome = await _viewModel.replaceAnswer();
    if (outcome == null || !mounted) return;
    _showOutcomeNotice(outcome);
  }

  void _showOutcomeNotice(ChatSaveOutcome outcome) {
    final message = switch (outcome) {
      ChatSaveOutcome.contentAdded =>
        widget.appendToTopic == null
            ? context.l10n.createAddTopicSuccess
            : context.l10n.appendAddedSuccess(_viewModel.appendTopicTitle!),
      ChatSaveOutcome.answerReplaced => context.l10n.answerReplaced,
      ChatSaveOutcome.saveFailed => context.l10n.createSaveError,
    };
    showDevmateNotice(
      context,
      message,
      kind: outcome == ChatSaveOutcome.saveFailed
          ? DevmateNoticeKind.error
          : DevmateNoticeKind.success,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title, overflow: TextOverflow.ellipsis),
      automaticallyImplyLeading: !kIsWeb,
      actions: [
        if (kIsWeb && widget.chatId != null)
          IconButton(
            tooltip: context.l10n.freeChatTitle,
            onPressed: () => context.go('/chat/free'),
            icon: const Icon(Icons.list_rounded),
          ),
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
          child: DevmateSpinner(size: 28, strokeWidth: 2.5),
        ),
        ChatSettingsPhase.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _viewModel.historyLoadFailed
                  ? context.l10n.chatHistoryReadError
                  : context.l10n.chatSettingsReadError(
                      '${_viewModel.settingsError}',
                    ),
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
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(
                child: _viewModel.messages.isEmpty
                    ? _buildEmpty()
                    : _buildMessages(),
              ),
              if (_viewModel.answerUpdate != null &&
                  widget.editQuestionId != null)
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
        ),
      ),
    );
  }

  Widget _buildNotConfigured() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.key_rounded, size: 44, color: context.colors.lavender),
          const SizedBox(height: 16),
          Text(
            context.l10n.chatKeyRequired,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.chatKeyRequiredDescription,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.muted, height: 1.5),
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
      if (_questionContext != null) ...[
        _messageItem(_questionContext!, streaming: false, retryable: false),
        const SizedBox(height: 24),
      ],
      Eyebrow(context.l10n.chatEyebrow, color: context.colors.muted),
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

  void _keepReadingPosition() {
    if (!_messageScroll.hasClients ||
        _messageScroll.position.pixels < 48 ||
        _scrollCorrectionScheduled) {
      return;
    }
    final before = _messageScroll.position.maxScrollExtent;
    final offset = _messageScroll.offset;
    _scrollCorrectionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollCorrectionScheduled = false;
      if (!mounted || !_messageScroll.hasClients) return;
      final position = _messageScroll.position;
      if (position.isScrollingNotifier.value ||
          (position.pixels - offset).abs() > 2 ||
          position.maxScrollExtent == before) {
        return;
      }
      _messageScroll.jumpTo(
        (offset + position.maxScrollExtent - before).clamp(
          0.0,
          position.maxScrollExtent,
        ),
      );
    });
  }

  Widget _messageItem(
    LlmChatMessage message, {
    required bool streaming,
    required bool retryable,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        onLongPress: () => _showMessageActions(message),
        child: GestureDetector(
          onLongPress: () => _showMessageActions(message),
          child: SelectionArea(
            contextMenuBuilder: (context, selection) =>
                flutter_material.AdaptiveTextSelectionToolbar.buttonItems(
                  anchors: selection.contextMenuAnchors,
                  buttonItems: [
                    flutter_material.ContextMenuButtonItem(
                      label: context.l10n.chatCopy,
                      onPressed: () {
                        selection.hideToolbar();
                        final text = _messageText(message);
                        if (text.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: text));
                        }
                      },
                    ),
                    flutter_material.ContextMenuButtonItem(
                      label: context.l10n.chatShare,
                      onPressed: () {
                        selection.hideToolbar();
                        _shareMessage(message);
                      },
                    ),
                  ],
                ),
            child: _Bubble(message: message, streaming: streaming),
          ),
        ),
      ),
      if (retryable)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.l10n.chatRetry),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
          ),
        ),
    ],
  );

  String _messageText(LlmChatMessage message) => message.failed
      ? context.llmErrorText(message.errorKind ?? LlmErrorKind.connection)
      : message.text;

  Future<void> _shareMessage(LlmChatMessage message) async {
    final text = _messageText(message);
    if (!mounted || text.isEmpty) return;
    final size = MediaQuery.sizeOf(context);
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        sharePositionOrigin: Rect.fromLTWH(
          size.width / 2,
          size.height / 2,
          1,
          1,
        ),
      ),
    );
  }

  Future<void> _showMessageActions(LlmChatMessage message) async {
    final action = !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS
        ? await showCupertinoModalPopup<String>(
            context: context,
            builder: (sheetContext) => CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(sheetContext).brightness,
                primaryColor: context.colors.accent,
                scaffoldBackgroundColor: context.colors.canvas,
                barBackgroundColor: context.colors.surfaceRaised,
              ),
              child: CupertinoActionSheet(
                actions: [
                  CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(sheetContext, 'copy'),
                    child: Text(context.l10n.chatCopy),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () => Navigator.pop(sheetContext, 'share'),
                    child: Text(context.l10n.chatShare),
                  ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(context.l10n.cancelAction),
                ),
              ),
            ),
          )
        : await showModalBottomSheet<String>(
            context: context,
            builder: (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.copy_rounded),
                    title: Text(context.l10n.chatCopy),
                    onTap: () => Navigator.pop(sheetContext, 'copy'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.share_rounded),
                    title: Text(context.l10n.chatShare),
                    onTap: () => Navigator.pop(sheetContext, 'share'),
                  ),
                ],
              ),
            ),
          );
    if (!mounted || action == null) return;
    final text = _messageText(message);
    if (text.isEmpty) return;
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
    } else if (action == 'share') {
      await _shareMessage(message);
    }
  }

  Widget _buildMessages() {
    final messages = _viewModel.messages;
    final current = _viewModel.session;
    if (!identical(current, _observedSession)) {
      _observedSession?.removeListener(_keepReadingPosition);
      _observedSession = current;
      current?.addListener(_keepReadingPosition);
    }
    return ListView.builder(
      controller: _messageScroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length + (_questionContext == null ? 0 : 1),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          return _messageItem(
            _questionContext!,
            streaming: false,
            retryable: false,
          );
        }
        final message = messages[messages.length - 1 - index];
        final isLast = index == 0;
        final session = _viewModel.session;
        if (!isLast || session == null) {
          return _messageItem(message, streaming: false, retryable: false);
        }

        return AnimatedBuilder(
          animation: session,
          builder: (context, _) => _messageItem(
            message,
            streaming: _viewModel.streaming,
            retryable: _viewModel.retryPrompt != null,
          ),
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
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(color: context.colors.border),
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
                  _inputFocus.unfocus();
                  _sendFromInput(text);
                },
                enabled: !_viewModel.streaming,
                style: TextStyle(
                  color: context.colors.primary,
                  fontSize: 16,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  filled: false,
                  hintText: context.l10n.chatInputHint,
                  hintStyle: TextStyle(color: context.colors.muted),
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
        _SendButton(
          onPressed: () => _sendFromInput(_input.text),
          enabled: !_viewModel.streaming,
        ),
      ],
    ),
  );

  @override
  void dispose() {
    final session = _observedSession;
    if (session != null) _detachObservedSession(session);
    _messageScroll.dispose();
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
    color: context.colors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: DevmateRadii.controlBorder,
      side: BorderSide(color: context.colors.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: DevmatePressable(
      borderRadius: DevmateRadii.controlBorder,
      enabled: enabled,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: DevmateSpacing.lg,
          vertical: 14,
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
          maxWidth: math.min(
            MediaQuery.of(context).size.width * (isUser ? 0.82 : 0.94),
            620,
          ),
        ),
        decoration: BoxDecoration(
          color: isUser ? context.colors.accent : context.colors.surface,
          border: isUser ? null : Border.all(color: context.colors.border),
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
                style: TextStyle(
                  color: context.colors.accentInk,
                  fontSize: 15.5,
                  height: 1.45,
                ),
              )
            : _assistantBody(context),
      ),
    );
  }

  Widget _assistantBody(BuildContext context) {
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
        : '${message.text}\n\n$errorText$detailSuffix';
    if (text.isEmpty && streaming) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: DevmateDotsLoader(dotSize: 7),
      );
    }
    if (!streaming) {
      final preview = replyPreviewMarkdown(text);
      if (preview != null) {
        return MarkdownBody(
          data: preview,
          softLineBreak: true,
          shrinkWrap: true,
          styleSheet: _assistantMarkdownStyle(context),
        );
      }
    }
    final markdown = _assistantMarkdownStyle(context);
    return MarkdownBody(
      data: streaming ? '$text ▍' : text,
      styleSheet: markdown,
      softLineBreak: true,
      shrinkWrap: true,
    );
  }

  MarkdownStyleSheet _assistantMarkdownStyle(BuildContext context) =>
      MarkdownStyleSheet.fromTheme(flutter_material.Theme.of(context)).copyWith(
        p: TextStyle(
          color: context.colors.primary,
          fontSize: 15.5,
          height: 1.5,
        ),
        strong: TextStyle(
          color: context.colors.primary,
          fontSize: 15.5,
          fontWeight: FontWeight.bold,
        ),
        em: TextStyle(
          color: context.colors.primary,
          fontSize: 15.5,
          fontStyle: FontStyle.italic,
        ),
        h1: TextStyle(
          color: context.colors.primary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        h2: TextStyle(
          color: context.colors.primary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        h3: TextStyle(
          color: context.colors.primary,
          fontSize: 16.5,
          fontWeight: FontWeight.bold,
        ),
        listBullet: TextStyle(
          color: context.colors.primary,
          fontSize: 15.5,
          height: 1.5,
        ),
        code: TextStyle(
          color: context.colors.accent,
          backgroundColor: context.colors.canvas,
          fontSize: 14,
        ),
        codeblockDecoration: BoxDecoration(
          color: context.colors.canvas,
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: context.colors.lavender, width: 3),
          ),
        ),
        a: TextStyle(color: context.colors.lavender),
        blockSpacing: 10,
      );
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

  final String? appendTitle;

  @override
  Widget build(BuildContext context) {
    final appendTitle = this.appendTitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: context.colors.accent),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              appendTitle ?? (draft.title ?? ''),
              style: TextStyle(
                color: context.colors.primary,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (appendTitle == null &&
                (draft.description?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 6),
              Text(
                draft.description!,
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              '${draft.questions.length} ${context.l10n.createAddedQuestionsSuffix(draft.questions.length)}',
              style: TextStyle(color: context.colors.lavender, fontSize: 14),
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
        color: context.colors.surface,
        border: Border.all(color: context.colors.accent),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.answerUpdateCardTitle,
            style: TextStyle(
              color: context.colors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (update.prompt.isNotEmpty) ...[
            Text(
              context.l10n.answerUpdatePromptLabel,
              style: TextStyle(color: context.colors.muted, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              update.prompt,
              style: TextStyle(
                color: context.colors.primary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            context.l10n.editAnswerLabel,
            style: TextStyle(color: context.colors.muted, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            update.answer,
            style: TextStyle(
              color: context.colors.primary,
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
      color: enabled ? context.colors.accent : context.colors.surface,
      shape: CircleBorder(
        side: BorderSide(
          color: enabled ? context.colors.accent : context.colors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: DevmatePressable(
        haptic: DevmateHapticImpact.light,
        borderRadius: BorderRadius.circular(24),
        enabled: enabled,
        onTap: onPressed,
        child: Center(
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 24,
            color: enabled ? context.colors.accentInk : context.colors.muted,
          ),
        ),
      ),
    ),
  );
}
