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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      unawaited(router.push('/chat/free'));
      await tester.pumpAndSettle();

      const inputHint = 'Ask anything…';
      expect(find.text(inputHint), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(2, 300));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(650, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

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
