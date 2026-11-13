import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/question_catalog.dart';
import 'ui/design_system.dart';
import 'ui/home_screen.dart';
import 'ui/practice_screen.dart';
import 'ui/topic_screen.dart';
import 'ui/training_view_model.dart';

GoRouter createRouter(TrainingViewModel viewModel) => GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => const NotFoundScreen(),
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomeScreen(viewModel: viewModel),
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
