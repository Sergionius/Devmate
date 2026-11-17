import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import 'data/app_preferences.dart';
import 'data/llm_settings.dart';
import 'data/topic_catalog.dart';
import '../l10n/l10n.dart';
import 'ui/chat_screen.dart';
import 'ui/edit_topic_screen.dart';
import 'ui/design_system.dart';
import 'ui/home_screen.dart';
import 'ui/practice_screen.dart';
import 'ui/settings_screen.dart';
import 'ui/topic_screen.dart';
import 'ui/training_view_model.dart';

CustomTransitionPage<Object?> _transitionPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  final theme = Theme.of(context);
  final duration =
      theme.pageTransitionsTheme.builders[theme.platform]?.transitionDuration ??
      const Duration(milliseconds: 300);
  return CustomTransitionPage<Object?>(
    key: state.pageKey,
    name: state.name ?? state.path,
    arguments: <String, String>{
      ...state.pathParameters,
      ...state.uri.queryParameters,
    },
    restorationId: state.pageKey.value,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        Theme.of(context).pageTransitionsTheme.buildTransitions(
          ModalRoute.of(context)! as PageRoute,
          context,
          animation,
          secondaryAnimation,
          child,
        ),
  );
}

GoRoute _route({
  required String path,
  required GoRouterWidgetBuilder builder,
  List<GoRoute> routes = const [],
}) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      _transitionPage(context, state, builder(context, state)),
  routes: routes,
);

GoRouter createRouter(
  TrainingViewModel viewModel,
  LlmSettingsRepository llmSettings,
  TopicCatalog catalog, {
  ValueNotifier<Locale?>? appLocale,
  ValueNotifier<bool>? aiDisabled,
  ValueNotifier<ThemeMode>? themeMode,
  AppPreferencesRepository? appPreferences,
}) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      _route(
        path: '/',
        builder: (context, state) => HomeScreen(
          viewModel: viewModel,
          catalog: catalog,
          settingsRepository: llmSettings,
          aiDisabled: aiDisabled,
        ),
      ),
      _route(
        path: '/settings',
        builder: (context, state) => SettingsScreen(
          appLocale: appLocale,
          aiDisabled: aiDisabled,
          themeMode: themeMode,
          appPreferences: appPreferences,
        ),
        routes: [
          _route(
            path: 'ai',
            builder: (context, state) =>
                AiSettingsScreen(settingsRepository: llmSettings),
          ),
          _route(
            path: 'data',
            builder: (context, state) => DataSettingsScreen(
              settingsRepository: llmSettings,
              catalog: catalog,
              viewModel: viewModel,
            ),
          ),
        ],
      ),
      _route(
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
      _route(
        path: '/chat/create/:topicId',
        builder: (context, state) {
          final topic = catalog.topicById(state.pathParameters['topicId']!);
          if (topic == null) return const NotFoundScreen();
          return ChatScreen(
            title: context.l10n.appendChatTitle(topic.title),
            systemPrompt: context.l10n.appendSystemPrompt(
              topic.title,
              topic.questions.map((q) => '- ${q.prompt}').join('\n'),
            ),
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
      _route(
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
      _route(
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
      _route(
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
            catalog: catalog,
            editQuestionId: question.id,
          );
        },
      ),
      _route(
        path: '/topic/:topicId',
        builder: (context, state) {
          final topic = catalog.topicById(state.pathParameters['topicId']!);
          if (topic == null) return const NotFoundScreen();
          return TopicScreen(
            topic: topic,
            viewModel: viewModel,
            catalog: catalog,
            aiDisabled: aiDisabled,
          );
        },
        routes: [
          _route(
            path: 'edit',
            builder: (context, state) {
              final topic = catalog.topicById(state.pathParameters['topicId']!);
              if (topic == null) return const NotFoundScreen();
              return EditTopicScreen(catalog: catalog, topicId: topic.id);
            },
          ),
          _route(
            path: 'edit/question/:questionId',
            builder: (context, state) {
              final topic = catalog.topicById(state.pathParameters['topicId']!);
              final questionId = state.pathParameters['questionId']!;
              final question = topic?.questions
                  .where((q) => q.id == questionId)
                  .firstOrNull;
              if (topic == null || question == null) {
                return const NotFoundScreen();
              }
              return ChatScreen(
                title: context.l10n.appendChatTitle(topic.title),
                systemPrompt: context.l10n.questionSystemPrompt(
                  question.prompt,
                  question.answer,
                ),
                intro: context.l10n.questionChatIntro,
                settingsRepository: llmSettings,
                catalog: catalog,
                editQuestionId: question.id,
                suggestions: [context.l10n.appendSuggestionEdgeCases],
              );
            },
          ),
          _route(
            path: 'practice/:index',
            builder: (context, state) {
              final topic = catalog.topicById(state.pathParameters['topicId']!);
              if (topic == null || topic.questions.isEmpty) {
                return const NotFoundScreen();
              }
              final index = int.tryParse(state.pathParameters['index']!) ?? 0;
              return PracticeScreen(
                topic: topic,
                initialIndex: index.clamp(0, topic.questions.length - 1),
                viewModel: viewModel,
                aiDisabled: aiDisabled,
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
