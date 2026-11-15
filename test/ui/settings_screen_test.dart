import 'package:devmate/data/llm_settings.dart';
import 'package:devmate/data/progress_repository.dart';
import 'package:devmate/data/topic_catalog.dart';
import 'package:devmate/l10n/app_localizations.dart';
import 'package:devmate/ui/settings_screen.dart';
import 'package:devmate/ui/training_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_secure_storage.dart';

class _MemoryProgress implements ProgressRepository {
  Map<String, int> scores = {};

  @override
  Future<Map<String, int>> load() async => {...scores};

  @override
  Future<void> save(Map<String, int> values) async {
    scores = {...values};
  }
}

void main() {
  testWidgets('сброс только прогресса сохраняет вопросы и настройки AI', (
    tester,
  ) async {
    final settings = LlmSettingsRepository(storage: MemorySecureStorage());
    const aiConfig = LlmSettings(
      baseUrl: 'https://example.org',
      model: 'test-model',
      apiKey: 'secret',
    );
    await settings.save(aiConfig);
    final catalog = TopicCatalog();
    final topic = await catalog.addUserTopic('Docker', 'Контейнеры', [
      ('Что такое образ?', 'Шаблон.'),
    ]);
    final progress = _MemoryProgress();
    final model = TrainingViewModel(progress, catalogRepository: catalog);
    await model.load();
    await model.record(topic.questions.single, knewAnswer: true);
    expect(model.points, 10);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(
          settingsRepository: settings,
          catalog: catalog,
          viewModel: model,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(OutlinedButton, 'Сбросить только прогресс');
    await tester.scrollUntilVisible(
      button,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button.first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Вопросы, темы и настройки AI сохранятся'),
      findsOneWidget,
    );
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(model.points, 10);
    await tester.tap(button.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сбросить только прогресс').last);
    await tester.pumpAndSettle();
    expect(model.completed, 0);
    expect(model.points, 0);
    expect(progress.scores, isEmpty);
    expect(
      catalog.topicById(topic.id)!.questions.single.prompt,
      'Что такое образ?',
    );
    final saved = await settings.load();
    expect(saved.toMap(), aiConfig.toMap());
  });

  // Регрессия на ревью-находку: _collect() терял authMode, из-за чего
  // выбранный Codex-режим не сохранялся и чат продолжал ходить по ключу.
  testWidgets(
    'choosing codex preset persists codexDeviceCode auth mode on save',
    (tester) async {
      final storage = MemorySecureStorage();
      final repo = LlmSettingsRepository(storage: storage);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(settingsRepository: repo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<LlmPreset>));
      await tester.pumpAndSettle(); // меню пресетов — без карточки логина
      await tester.tap(find.text('ChatGPT Codex (подписка)').last);
      // Карточка логина содержит CircularProgressIndicator — его анимация
      // никогда не «успокаивается», поэтому только конечные пульсы.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // анимация снекбара

      final loaded = await repo.load();
      expect(loaded.authMode, LlmAuthMode.codexDeviceCode);
      expect(loaded.baseUrl, 'https://chatgpt.com/backend-api/codex');
      expect(loaded.model, 'gpt-6-luna');
    },
  );
}
