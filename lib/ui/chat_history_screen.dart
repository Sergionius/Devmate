import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/chat_history_repository.dart';
import '../l10n/l10n.dart';
import 'design_system.dart';
import 'platform_ui.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key, required this.repository});

  final ChatHistoryRepository repository;

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  late Future<List<SavedChat>> _chats = widget.repository.list();
  bool _busy = false;

  void _reload() => setState(() {
    _chats = widget.repository.list();
  });

  Future<void> _newChat() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final chat = await widget.repository.create();
      if (!mounted) return;
      await context.push('/chat/free/${chat.id}');
      if ((await widget.repository.loadMessages(chat.id)).isEmpty) {
        await widget.repository.delete(chat.id);
      }
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        showDevmateNotice(
          context,
          context.l10n.chatHistoryWriteError,
          kind: DevmateNoticeKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(SavedChat chat) async {
    await context.push('/chat/free/${chat.id}');
    if (mounted) _reload();
  }

  Future<void> _delete(SavedChat chat) async {
    final confirmed = await showDevmateConfirm(
      context,
      title: context.l10n.chatDeleteTitle,
      message: context.l10n.chatDeleteWarning,
      confirmLabel: context.l10n.chatDeleteTitle,
      cancelLabel: context.l10n.cancelAction,
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.delete(chat.id);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        showDevmateNotice(
          context,
          context.l10n.chatHistoryWriteError,
          kind: DevmateNoticeKind.error,
        );
      }
    }
  }

  bool _isIos(BuildContext context) =>
      !kIsWeb && Theme.of(context).platform == TargetPlatform.iOS;

  bool _isAndroid(BuildContext context) =>
      !kIsWeb && Theme.of(context).platform == TargetPlatform.android;

  Widget _chatTile(BuildContext context, SavedChat chat, String date) {
    final tile = ListTile(
      title: Text(
        chat.title.isEmpty ? context.l10n.chatNew : chat.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(date),
      onTap: () => _open(chat),
      trailing: _isIos(context)
          ? null
          : IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: context.l10n.chatDeleteTitle,
              onPressed: () => _delete(chat),
            ),
    );
    if (!_isIos(context)) return Card(child: tile);

    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: context.l10n.chatDeleteTitle): () =>
            _delete(chat),
      },
      child: Dismissible(
        key: ValueKey(chat.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          await _delete(chat);
          return false; // The repository reload removes the row after confirmation.
        },
        background: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsetsDirectional.only(end: 20),
          alignment: AlignmentDirectional.centerEnd,
          decoration: BoxDecoration(
            color: context.colors.error,
            borderRadius: DevmateRadii.cardBorder,
          ),
          child: const Icon(CupertinoIcons.delete, color: Colors.white),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: context.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: DevmateRadii.cardBorder,
              side: BorderSide(color: context.colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: tile,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.freeChatTitle),
      actions: [
        if (!_isAndroid(context))
          IconButton(
            tooltip: context.l10n.chatNew,
            onPressed: _busy ? null : _newChat,
            icon: Icon(
              _isIos(context)
                  ? CupertinoIcons.square_pencil
                  : Icons.add_rounded,
            ),
          ),
      ],
    ),
    floatingActionButton: _isAndroid(context)
        ? FloatingActionButton.extended(
            onPressed: _busy ? null : _newChat,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.chatNew),
          )
        : null,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: FutureBuilder<List<SavedChat>>(
          future: _chats,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.l10n.chatHistoryReadError),
                    TextButton(
                      onPressed: _reload,
                      child: Text(context.l10n.chatRetry),
                    ),
                  ],
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: DevmateSpinner(size: 28, strokeWidth: 2.5),
              );
            }
            final chats = snapshot.data!;
            if (chats.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.chatHistoryEmpty,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                _isAndroid(context) ? 88 : 16,
              ),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final date = MaterialLocalizations.of(context)
                    .formatMediumDate(chat.updatedAt.toLocal());
                return _chatTile(context, chat, date);
              },
            );
          },
        ),
      ),
    ),
  );
}
