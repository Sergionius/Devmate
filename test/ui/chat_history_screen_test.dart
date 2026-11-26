import 'package:devmate/data/chat_history_repository.dart';
import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/chat_history_screen.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  testWidgets('lists conversations and confirms deletion', (tester) async {
    final history = ChatHistoryRepository(
      openDatabase: () => databaseFactoryMemory.openDatabase('history-widget'),
    );
    final chat = await tester.runAsync(() async {
      final created = await history.create();
      await history.saveMessages(created.id, [
        LlmChatMessage(LlmRole.user, 'Interview prep'),
      ]);
      return created;
    });
    expect(chat, isNotNull);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ChatHistoryScreen(repository: history),
        ),
        GoRoute(
          path: '/chat/free/:chatId',
          builder: (_, _) => const Scaffold(body: Text('Conversation')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: devmateTheme(),
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Interview prep'), findsOneWidget);
    await tester.tap(find.text('Interview prep'));
    await tester.pumpAndSettle();
    expect(find.text('Conversation'), findsOneWidget);
    router.pop();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete conversation'));
    await tester.pumpAndSettle();
    expect(await tester.runAsync(history.list), hasLength(1));
    await tester.tap(find.text('Delete conversation').last);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(await tester.runAsync(history.list), isEmpty);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    expect(find.textContaining('No conversations yet'), findsOneWidget);
  });
}
