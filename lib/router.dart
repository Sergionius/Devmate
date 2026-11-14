import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/llm_settings.dart';
import 'data/question_catalog.dart';
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
) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            HomeScreen(viewModel: viewModel, settingsRepository: llmSettings),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            SettingsScreen(settingsRepository: llmSettings),
      ),
      GoRoute(
        path: '/chat/topic/:topicId',
        builder: (context, state) {
          final topic = topicById(state.pathParameters['topicId']!);
          if (topic == null) return const NotFoundScreen();
          return ChatScreen(
            title: 'AI · ${topic.title}',
            systemPrompt:
                'Ты — технический интервьюер, готовишь пользователя к собеседованию по теме "${topic.title}" (${topic.description}). '
                'Отвечай по-русски, кратко и по делу: объясняй примерами, задавай наводящие вопросы, проверяй понимание. '
                'Не решай за пользователя, пока он не попробовал сам.',
            settingsRepository: llmSettings,
            suggestions: const [
              'С чего начать подготовку по этой теме?',
              'Задай мне 3 типичных вопроса с собеседования',
              'Разбери одну тему простыми словами с примером',
            ],
          );
        },
      ),
      GoRoute(
        path: '/chat/question/:topicId/:index',
        builder: (context, state) {
          final topic = topicById(state.pathParameters['topicId']!);
          final index = int.tryParse(state.pathParameters['index']!) ?? 0;
          final question =
              (topic == null || index < 0 || index >= topic.questions.length)
              ? null
              : topic.questions[index];
          if (question == null) return const NotFoundScreen();
          final draft = (state.extra is String) ? state.extra as String : '';
          return ChatScreen(
            title: 'AI · Вопрос ${index + 1}',
            systemPrompt:
                'Ты — технический интервьюер. Разбираешь с пользователем вопрос: "${question.prompt}". '
                'Эталонный ответ для тебя: "${question.answer}". '
                '${draft.isNotEmpty ? 'Черновик ответа пользователя: "$draft". ' : ''}'
                'Отвечай по-русски: не выдавай сразу весь эталон — наводящими вопросами и примерами помоги пользователю '
                'сформулировать ответ самому, затем сверь с эталоном и укажи, что стоит добавить.',
            settingsRepository: llmSettings,
          );
        },
      ),
      GoRoute(
        path: '/topic/:topicId',
        builder: (context, state) {
          final topic = topicById(state.pathParameters['topicId']!);
          if (topic == null) return const NotFoundScreen();
          return TopicScreen(topic: topic, viewModel: viewModel);
        },
        routes: [
          GoRoute(
            path: 'practice/:index',
            builder: (context, state) {
              final topic = topicById(state.pathParameters['topicId']!);
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
          const Text(
            'Такой страницы нет.',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('На главную'),
          ),
        ],
      ),
    ),
  );
}
