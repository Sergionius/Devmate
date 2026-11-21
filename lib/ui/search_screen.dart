import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/catalog_search.dart';
import '../data/topic_catalog.dart';
import '../l10n/l10n.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.catalog});

  final TopicCatalog catalog;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  bool _includeAnswers = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
  }

  void _update() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_update);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.searchTitle)),
    body: ListenableBuilder(
      listenable: widget.catalog,
      builder: (context, _) {
        final query = _controller.text.trim();
        final results = searchCatalog(
          widget.catalog.topics,
          query,
          includeAnswers: _includeAnswers,
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.l10n.searchHint,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.l10n.searchClear,
                            onPressed: _controller.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FilterChip(
                    label: Text(context.l10n.searchAnswers),
                    selected: _includeAnswers,
                    onSelected: (value) =>
                        setState(() => _includeAnswers = value),
                  ),
                ),
                const SizedBox(height: 20),
                if (query.isEmpty)
                  Text(context.l10n.searchStart)
                else if (results.topics.isEmpty && results.questions.isEmpty)
                  Text(context.l10n.searchEmpty)
                else ...[
                  if (results.topics.isNotEmpty) ...[
                    Text(
                      context.l10n.searchTopics,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final topic in results.topics)
                      ListTile(
                        title: Text(topic.title),
                        subtitle: Text(
                          topic.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => context.push(
                          '/topic/${Uri.encodeComponent(topic.id)}',
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                  if (results.questions.isNotEmpty) ...[
                    Text(
                      context.l10n.searchQuestions,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    for (final hit in results.questions)
                      ListTile(
                        title: Text(hit.question.prompt),
                        subtitle: Text(
                          hit.inAnswer
                              ? '${hit.topic.title} · ${hit.question.answer}'
                              : hit.topic.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => context.push(
                          '/topic/${Uri.encodeComponent(hit.topic.id)}/practice/${hit.index}',
                        ),
                      ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
