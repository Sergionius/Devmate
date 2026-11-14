import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/llm_settings.dart';
import 'data/topic_catalog.dart';
import '../l10n/l10n.dart';
import 'ui/chat_screen.dart';
import 'ui/design_system.dart';
import 'ui/home_screen.dart';
import 'ui/practice_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/topic_screen.dart';
import 'ui/training_view_model.dart';

GoRouter createRouter(
  TrainingViewModel viewModel,
  LlmSettingsRepository llmSettings,
  TopicCatalog catalog,
) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(
          viewModel: viewModel,
          catalog: catalog,
          settingsRepository: llmSettings,
        ),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            SettingsScreen(settingsRepository: llmSettings),
      ),
      GoRoute(
        path: '/chat/free',
        builder: (context, state) => ChatScreen(
          title: context.l10n.freeChatTitle,
          systemPrompt: context.l10n.freeSystemPrompt,
          intro: context.l10n.freeChatIntro,
          settingsRepository: llmSettings,
          suggestions: [
            context.l10n.freeSuggestionIcebreaker,
            context.l10n.freeSuggestionCareer,
            context.l10n.freeSuggestionFun,
          ],
        ),
      ),
      GoRoute(
        path: '/chat/create/:topicId',
        builder: (context, state) {
          final topic = catalog.topicById(state.pathParameters['topicId']!);
          if (topic == null) return const NotFoundScreen();
          return ChatScreen(
            title: context.l10n.appendChatTitle(topic.title),
            systemPrompt: context.l10n.appendSystemPrompt(topic.title),
            intro: context.l10n.appendChatIntro,
            settingsRepository: llmSettings,
            catalog: catalog,
            appendToTopic: topic.id,
            suggestions: [
              context.l10n.appendSuggestionBasics(topic.title),
              context.l10n.appendSuggestionPractice(topic.title),
              context.l10n.appendSuggestionEdgeCases,
            ],
          );
        },
      ),
      GoRoute(
        path: '/chat/create',
        builder: (context, state) => ChatScreen(
          title: context.l10n.createChatTitle,
          systemPrompt: context.l10n.createSystemPrompt,
          intro: context.l10n.createChatIntro,
          settingsRepository: llmSettings,
          catalog: catalog,
          suggestions: [
            context.l10n.createSuggestionDocker,
            context.l10n.createSuggestionTypescript,
            context.l10n.createSuggestionSql,
          ],
        ),
      ),
      GoRoute(
        path: '/chat/topic/:topicId',
        builder: (context, state) {
          final topic = catalog.topicById(state.pathParameters['topicId']!);
          if (topic == null) return const NotFoundScreen();
          return ChatScreen(
            title: context.l10n.topicChatTitle(topic.title),
            systemPrompt: context.l10n.topicSystemPrompt(
              topic.title,
              topic.description,
            ),
            intro: context.l10n.topicChatIntro,
            settingsRepository: llmSettings,
            suggestions: [
              context.l10n.topicSuggestionStart,
              context.l10n.topicSuggestionQuiz,
              context.l10n.topicSuggestionExplainer,
            ],
          );
        },
      ),
      GoRoute(
        path: '/chat/question/:topicId/:index',
        builder: (context, state) {
          final topic = catalog.topicById(state.pathParameters['topicId']!);
          final index = int.tryParse(state.pathParameters['index']!) ?? 0;
          final question =
              (topic == null || index < 0 || index >= topic.questions.length)
              ? null
              : topic.questions[index];
          if (question == null) return const NotFoundScreen();
          final draft = (state.extra is String) ? state.extra as String : '';
          return ChatScreen(
            title: context.l10n.questionChatTitle(index + 1),
            systemPrompt:
                context.l10n.questionSystemPrompt(
                  question.prompt,
                  question.answer,
                ) +
                (draft.isNotEmpty ? context.l10n.questionDraftPart(draft) : ''),
            intro: context.l10n.questionChatIntro,
            settingsRepository: llmSettings,
          );
        },
      ),
      GoRoute(
        path: '/topic/:topicId',
        builder: (context, state) {
          final topic = catalog.topicById(state.pathParameters['topicId']!);
          if (topic == null) return const NotFoundScreen();
          return TopicScreen(topic: topic, viewModel: viewModel);
        },
        routes: [
          GoRoute(
            path: 'practice/:index',
            builder: (context, state) {
              final topic = catalog.topicById(state.pathParameters['topicId']!);
              if (topic == null) return const NotFoundScreen();
              final index = int.tryParse(state.pathParameters['index']!) ?? 0;
              return PracticeScreen(
                topic: topic,
                initialIndex: index.clamp(0, topic.questions.length - 1),
                viewModel: viewModel,
              );
            },
          ),
        ],
      ),
    ],
  );
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('devmate')),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Eyebrow('404'),
          const SizedBox(height: 12),
          Text(
            context.l10n.pageNotFound,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/'),
            child: Text(context.l10n.goHome),
          ),
        ],
      ),
    ),
  );
}
