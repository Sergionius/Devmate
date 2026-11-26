import 'package:devmate/data/chat_history_repository.dart';
import 'package:devmate/data/llm_chat_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  var counter = 0;
  ChatHistoryRepository repository() => ChatHistoryRepository(
    openDatabase: () => databaseFactoryMemory.openDatabase('chat-${counter++}'),
  );

  List<LlmChatMessage> transcript(String question) => [
    LlmChatMessage(LlmRole.user, question),
    LlmChatMessage(LlmRole.assistant, 'Hello!'),
  ];

  test(
    'creates, persists messages and lists most recent chats first',
    () async {
      final history = repository();
      final first = await history.create();
      await history.saveMessages(first.id, transcript('First question'));
      final second = await history.create();
      await history.saveMessages(second.id, transcript('Second question'));
      expect((await history.list()).map((chat) => chat.title), [
        'Second question',
        'First question',
      ]);
      expect((await history.loadMessages(first.id)).map((m) => m.text), [
        'First question',
        'Hello!',
      ]);
      await history.delete(first.id);
      expect(await history.get(first.id), isNull);
      expect(await history.loadMessages(first.id), isEmpty);
    },
  );

  test('failed replies and retries round-trip', () async {
    final history = repository();
    final chat = await history.create();
    final failed = LlmChatMessage(LlmRole.assistant, '', failed: true)
      ..errorKind = LlmErrorKind.rateLimited;
    await history.saveMessages(chat.id, [
      LlmChatMessage(LlmRole.user, 'Hi'),
      failed,
    ]);
    final saved = await history.loadMessages(chat.id);
    expect(saved.last.failed, isTrue);
    expect(saved.last.errorKind, LlmErrorKind.rateLimited);
    await history.saveMessages(chat.id, transcript('Hi'));
    expect((await history.loadMessages(chat.id)).last.text, 'Hello!');
  });

  test(
    'export, merge idempotently, resolve collisions, replace, preserve empty',
    () async {
      final source = repository();
      final first = await source.create();
      await source.saveMessages(first.id, transcript('Original'));
      final archive = await source.export();
      final target = repository();
      await target.import(archive, merge: true);
      await target.import(archive, merge: true);
      expect(await target.list(), hasLength(1));
      final conflict = ChatArchive(
        SavedChat(id: first.id, title: 'Different', updatedAt: DateTime.now()),
        transcript('Different'),
      );
      await target.import([conflict], merge: true);
      await target.import([conflict], merge: true);
      expect(await target.list(), hasLength(2));
      await target.import([], merge: false);
      expect(await target.list(), isEmpty);
    },
  );

  test('rejects invalid archive messages before changing local data', () async {
    final history = repository();
    final chat = await history.create();
    expect(
      () => ChatArchive.parse({
        ...chat.toJson(),
        'messages': [
          {'role': 'system', 'text': 'unexpected'},
        ],
      }),
      throwsFormatException,
    );
    expect(await history.get(chat.id), isNotNull);
  });

  test(
    'empty chats are hidden and not exported; deleted chats reject writes',
    () async {
      final history = repository();
      final empty = await history.create();
      expect(await history.list(), isEmpty);
      expect(await history.export(), isEmpty);
      await history.delete(empty.id);
      await expectLater(
        history.saveMessages(empty.id, transcript('Lost')),
        throwsStateError,
      );
      expect(await history.get(empty.id), isNull);
    },
  );
}
