import 'package:devmate/data/chat_history_repository.dart';
import 'package:devmate/data/llm_chat_provider.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/chat_history_screen.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  testWidgets('empty history opens a new chat and back does not loop', (
    tester,
  ) async {
    final history = ChatHistoryRepository(
      openDatabase: () => databaseFactoryMemory.openDatabase('empty-history'),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/chat/free'),
              child: const Text('Open chats'),
            ),
          ),
        ),
        GoRoute(
          path: '/chat/free',
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
    await tester.tap(find.text('Open chats'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Conversation'), findsOneWidget);
    final id = GoRouterState.of(tester.element(find.text('Conversation')))
        .pathParameters['chatId']!;
    expect(await tester.runAsync(() => history.get(id)), isNotNull);

    router.pop();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open chats'), findsOneWidget);
    expect(await tester.runAsync(history.list), isEmpty);
  });

  testWidgets('lists conversations and confirms deletion on Android', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
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
    expect(find.byType(FloatingActionButton), findsOneWidget);
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

  testWidgets(
    'iOS uses a compose action and swipe-to-delete without a trailing trash button',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final history = ChatHistoryRepository(
        openDatabase: () =>
            databaseFactoryMemory.openDatabase('history-ios-widget'),
      );
      await tester.runAsync(() async {
        final chat = await history.create();
        await history.saveMessages(chat.id, [
          LlmChatMessage(LlmRole.user, 'Interview prep'),
        ]);
      });
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
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byTooltip('New chat'), findsOneWidget);
      expect(find.byTooltip('Delete conversation'), findsNothing);
      expect(find.text('Interview prep'), findsOneWidget);

      await tester.drag(find.text('Interview prep'), const Offset(-550, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete conversation'), findsWidgets);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await tester.runAsync(history.list), hasLength(1));

      await tester.drag(find.text('Interview prep'), const Offset(-550, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete conversation').last);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(await tester.runAsync(history.list), isEmpty);
    },
  );
}
