import 'dart:convert';

import 'package:sembast/sembast.dart';

import 'chat_history_factory_io.dart'
    if (dart.library.js_interop) 'chat_history_factory_web.dart'
    as platform;
import 'llm_chat_provider.dart';

class SavedChat {
  const SavedChat({
    required this.id,
    required this.title,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  static SavedChat parse(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid chat');
    final id = raw['id'];
    final title = raw['title'];
    final date = raw['updatedAt'];
    if (id is! String ||
        id.isEmpty ||
        title is! String ||
        date is! String ||
        DateTime.tryParse(date) == null) {
      throw const FormatException('Invalid chat metadata');
    }
    return SavedChat(id: id, title: title, updatedAt: DateTime.parse(date));
  }
}

class ChatArchive {
  const ChatArchive(this.chat, this.messages);

  final SavedChat chat;
  final List<LlmChatMessage> messages;

  Map<String, Object?> toJson() => {
    ...chat.toJson(),
    // Provider diagnostics may contain sensitive URLs or request details.
    'messages': [for (final message in messages) _backupMessage(message)],
  };

  static ChatArchive parse(Object? raw) {
    final chat = SavedChat.parse(raw);
    final messages = (raw as Map)['messages'];
    if (messages is! List) throw const FormatException('Invalid messages');
    return ChatArchive(chat, [
      for (final item in messages) messageFromJson(item),
    ]);
  }
}

Map<String, Object?> _backupMessage(LlmChatMessage message) =>
    {...messageToJson(message)}..remove('errorDetail');

Map<String, Object?> messageToJson(LlmChatMessage message) => {
  'role': message.role.name,
  'text': message.text,
  if (message.failed) 'failed': true,
  if (message.errorKind != null) 'errorKind': message.errorKind!.name,
  if (message.errorDetail != null) 'errorDetail': message.errorDetail,
};

LlmChatMessage messageFromJson(Object? raw) {
  if (raw is! Map ||
      raw['text'] is! String ||
      (raw['role'] != 'user' && raw['role'] != 'assistant') ||
      (raw['failed'] != null && raw['failed'] is! bool) ||
      (raw['errorKind'] != null && raw['errorKind'] is! String) ||
      (raw['errorDetail'] != null && raw['errorDetail'] is! String)) {
    throw const FormatException('Invalid chat message');
  }
  final kind = raw['errorKind'];
  return LlmChatMessage(
      raw['role'] == 'user' ? LlmRole.user : LlmRole.assistant,
      raw['text'] as String,
      failed: raw['failed'] == true,
    )
    ..errorKind = kind == null
        ? null
        : LlmErrorKind.values.where((value) => value.name == kind).firstOrNull
    ..errorDetail = raw['errorDetail'] as String?;
}

/// One metadata record and individual message records per conversation.
/// The same Sembast API uses a local file on native and IndexedDB on web.
class ChatHistoryRepository {
  ChatHistoryRepository({Future<Database> Function()? openDatabase})
    : _open = openDatabase ?? platform.openChatHistoryDatabase;

  final Future<Database> Function() _open;
  Future<Database>? _database;
  final _chats = stringMapStoreFactory.store('chats');
  final _messages = stringMapStoreFactory.store('messages');
  int _nextId = 0;

  Future<Database> get database => _database ??= _open();

  Future<List<SavedChat>> list() async {
    final records = await _chats.find(await database);
    final chats = <SavedChat>[];
    for (final record in records) {
      try {
        final chat = SavedChat.parse(record.value);
        if (chat.title.isNotEmpty) chats.add(chat);
      } on FormatException {
        // A corrupt record must not hide the other conversations.
      }
    }
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  }

  Future<SavedChat?> get(String id) async {
    final value = await _chats.record(id).get(await database);
    return value == null ? null : SavedChat.parse(value);
  }

  Future<SavedChat> create() async {
    final db = await database;
    late SavedChat chat;
    await db.transaction((transaction) async {
      do {
        final id = '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
        chat = SavedChat(id: id, title: '', updatedAt: DateTime.now());
      } while (await _chats.record(chat.id).exists(transaction));
      await _chats.record(chat.id).put(transaction, chat.toJson());
    });
    return chat;
  }

  Future<List<LlmChatMessage>> loadMessages(String id) async {
    final records = await _messages.find(
      await database,
      finder: Finder(
        filter: Filter.equals('chatId', id),
        sortOrders: [SortOrder('index')],
      ),
    );
    return [for (final record in records) messageFromJson(record.value)];
  }

  Future<void> saveMessages(String id, List<LlmChatMessage> messages) async {
    final db = await database;
    await db.transaction((transaction) async {
      final existing = await _chats.record(id).get(transaction);
      if (existing == null) {
        throw StateError('This conversation was deleted or does not exist');
      }
      final previous = await _messages.find(
        transaction,
        finder: Finder(filter: Filter.equals('chatId', id)),
      );
      for (final record in previous) {
        final index = record.value['index'];
        if (index is! int || index >= messages.length) {
          await _messages.record(record.key).delete(transaction);
        }
      }
      for (var index = 0; index < messages.length; index++) {
        await _messages.record('$id:$index').put(transaction, {
          'chatId': id,
          'index': index,
          ...messageToJson(messages[index]),
        });
      }
      final original = SavedChat.parse(existing);
      final first = messages
          .where((message) => message.role == LlmRole.user)
          .firstOrNull;
      final title = first == null
          ? original.title
          : first.text.trim().replaceAll(RegExp(r'\s+'), ' ');
      final updated = SavedChat(
        id: id,
        title: title.runes.length > 60
            ? '${String.fromCharCodes(title.runes.take(60))}…'
            : title,
        updatedAt: DateTime.now(),
      );
      await _chats.record(id).put(transaction, updated.toJson());
    });
  }

  Future<void> delete(String id) async {
    final db = await database;
    await db.transaction((transaction) async {
      await _messages.delete(
        transaction,
        finder: Finder(filter: Filter.equals('chatId', id)),
      );
      await _chats.record(id).delete(transaction);
    });
  }

  Future<List<ChatArchive>> export() async {
    final db = await database;
    return db.transaction((transaction) async {
      final result = <ChatArchive>[];
      final chats = await _chats.find(transaction);
      for (final record in chats) {
        final chat = SavedChat.parse(record.value);
        if (chat.title.isEmpty) continue;
        final messages = await _messages.find(
          transaction,
          finder: Finder(
            filter: Filter.equals('chatId', chat.id),
            sortOrders: [SortOrder('index')],
          ),
        );
        result.add(
          ChatArchive(chat, [
            for (final message in messages) messageFromJson(message.value),
          ]),
        );
      }
      return result;
    });
  }

  bool _sameArchive(
    SavedChat candidate,
    List<RecordSnapshot<String, Map<String, Object?>>> records,
    ChatArchive archive,
  ) =>
      candidate.title == archive.chat.title &&
      candidate.updatedAt.isAtSameMomentAs(archive.chat.updatedAt) &&
      records.length == archive.messages.length &&
      List.generate(
        records.length,
        (index) =>
            jsonEncode(_backupMessage(messageFromJson(records[index].value))) ==
            jsonEncode(_backupMessage(archive.messages[index])),
      ).every((same) => same);

  /// Replace only when the backup explicitly contains a chats field.
  /// Merge preserves matching IDs and reassigns IDs for different collisions.
  Future<void> import(List<ChatArchive> incoming, {required bool merge}) async {
    final db = await database;
    await db.transaction((transaction) async {
      if (!merge) {
        await _messages.delete(transaction);
        await _chats.delete(transaction);
      }
      for (final archive in incoming) {
        var chat = archive.chat;
        final existing = await _chats.record(chat.id).get(transaction);
        if (existing != null) {
          final existingMessages = await _messages.find(
            transaction,
            finder: Finder(
              filter: Filter.equals('chatId', chat.id),
              sortOrders: [SortOrder('index')],
            ),
          );
          final same = _sameArchive(
            SavedChat.parse(existing),
            existingMessages,
            archive,
          );
          if (same) continue;
          // A previous merge may have reassigned this archive's ID. Avoid
          // creating another copy when the same backup is imported again.
          final allRecords = await _chats.find(transaction);
          var alreadyImported = false;
          for (final record in allRecords) {
            final candidate = SavedChat.parse(record.value);
            if (candidate.id == chat.id || candidate.title != chat.title) {
              continue;
            }
            final candidateMessages = await _messages.find(
              transaction,
              finder: Finder(
                filter: Filter.equals('chatId', candidate.id),
                sortOrders: [SortOrder('index')],
              ),
            );
            if (_sameArchive(candidate, candidateMessages, archive)) {
              alreadyImported = true;
              break;
            }
          }
          if (alreadyImported) continue;
          String newId;
          do {
            newId = '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
          } while (await _chats.record(newId).exists(transaction));
          chat = SavedChat(
            id: newId,
            title: chat.title,
            updatedAt: chat.updatedAt,
          );
        }
        await _chats.record(chat.id).put(transaction, chat.toJson());
        for (var index = 0; index < archive.messages.length; index++) {
          await _messages.record('${chat.id}:$index').put(transaction, {
            'chatId': chat.id,
            'index': index,
            ...messageToJson(archive.messages[index]),
          });
        }
      }
    });
  }
}
