import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:go_router/go_router.dart';

import '../data/llm_chat_provider.dart';
import '../data/llm_settings.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.title,
    required this.systemPrompt,
    required this.settingsRepository,
    this.suggestions = const [],
  });

  final String title;
  final String systemPrompt;
  final LlmSettingsRepository settingsRepository;
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
    } finally {
      if (mounted) setState(() => _streaming = false);
    }
  }

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
      Text(
        widget.suggestions.isEmpty
            ? context.l10n.questionChatIntro
            : context.l10n.topicChatIntro,
        style: const TextStyle(fontSize: 18, height: 1.45),
      ),
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
