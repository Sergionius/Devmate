import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/router.dart';
import 'package:devmate/ui/design_system.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

import 'dart:async';

/// Регрессионный тест iOS edge-swipe back.
///
/// go_router 18 не распознаёт MaterialApp (его isMaterialApp() ищет класс из
/// material_ui), и builder-маршруты получают NoTransitionPage — без
/// Cupertino-перехода и жеста «назад». createRouter строит страницы через
/// _transitionPage с переходами из PageTransitionsTheme; тест проверяет, что
/// свайп от левого края реально возвращает на предыдущий маршрут.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final storage = MemorySecureStorage()
    ..values['llm.baseUrl'] = 'https://example.com/v1'
    ..values['llm.model'] = 'test-model'
    ..values['llm.apiKey'] = 'test-key';

  testWidgets('edge swipe from the left pops the pushed route on iOS', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final model = TrainingViewModel(
        _MemoryProgressRepository(),
        catalogRepository: TopicCatalog(),
      )..load();
      final router = createRouter(
        model,
        LlmSettingsRepository(storage: storage),
        TopicCatalog(),
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: devmateTheme(),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      // push завершается только при pop маршрута — не ждём его.
      unawaited(router.push('/chat/free'));
      await tester.pumpAndSettle();
      // Чат реально открылся и загрузил настройки (поле ввода на экране).
      const inputHint = 'Спросите что угодно…';
      expect(find.text(inputHint), findsOneWidget);

      // Свайп от левого края: тянем дальше половины ширины экрана.
      final gesture = await tester.startGesture(const Offset(2, 300));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(650, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Маршрут вернулся на домашний экран.
      expect(find.text(inputHint), findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/');
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

class _MemoryProgressRepository implements ProgressRepository {
  Map<String, int> scores = {};

  @override
  Future<Map<String, int>> load() async => {...scores};

  @override
  Future<void> save(Map<String, int> scores) async {
    this.scores = {...scores};
  }
}
