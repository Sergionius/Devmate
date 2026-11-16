import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/question.dart';
import 'question_catalog.dart';

abstract class UserTopicsRepository {
  Future<List<Map<String, dynamic>>> load();

  Future<void> save(List<Map<String, dynamic>> topics);

  Future<Map<String, List<Map<String, dynamic>>>> loadExtra();

  Future<void> saveExtra(Map<String, List<Map<String, dynamic>>> extra);

  Future<Map<String, dynamic>> loadOverrides();

  Future<void> saveOverrides(Map<String, dynamic> overrides);
}

class LocalUserTopicsRepository implements UserTopicsRepository {
  LocalUserTopicsRepository(this._preferences);

  static const _key = 'devmate.user_topics.v1';
  static const _extraKey = 'devmate.user_questions.v1';
  static const _overridesKey = 'devmate.catalog_overrides.v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<List<Map<String, dynamic>>> load() async {
    final raw = await _preferences.getString(_key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>) item,
      ];
    } on FormatException {
      return [];
    }
  }

  @override
  Future<void> save(List<Map<String, dynamic>> topics) async {
    await _preferences.setString(_key, jsonEncode(topics));
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> loadExtra() async {
    final raw = await _preferences.getString(_extraKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return {
        for (final entry in decoded.entries)
          if (entry.value is List)
            entry.key: [
              for (final item in entry.value as List)
                if (item is Map<String, dynamic>) item,
            ],
      };
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> saveExtra(Map<String, List<Map<String, dynamic>>> extra) async {
    await _preferences.setString(_extraKey, jsonEncode(extra));
  }

  @override
  Future<Map<String, dynamic>> loadOverrides() async {
    final raw = await _preferences.getString(_overridesKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return {};
      return decoded;
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> saveOverrides(Map<String, dynamic> overrides) async {
    await _preferences.setString(_overridesKey, jsonEncode(overrides));
  }
}

class CatalogOverrides {
  CatalogOverrides({
    Map<String, (String, String)>? questionEdits,
    Set<String>? deletedQuestionIds,
    Map<String, (String, String)>? topicEdits,
  }) : questionEdits = questionEdits ?? {},
       deletedQuestionIds = deletedQuestionIds ?? {},
       topicEdits = topicEdits ?? {};

  final Map<String, (String, String)> questionEdits;
  final Set<String> deletedQuestionIds;

  final Map<String, (String, String)> topicEdits;

  bool get isEmpty =>
      questionEdits.isEmpty && deletedQuestionIds.isEmpty && topicEdits.isEmpty;

  Map<String, dynamic> toJson() => {
    'questionEdits': {
      for (final entry in questionEdits.entries)
        entry.key: {'prompt': entry.value.$1, 'answer': entry.value.$2},
    },
    'deletedQuestionIds': [...deletedQuestionIds],
    'topicEdits': {
      for (final entry in topicEdits.entries)
        entry.key: {'title': entry.value.$1, 'description': entry.value.$2},
    },
  };

  static CatalogOverrides fromJson(Map<String, dynamic> json) {
    final result = CatalogOverrides();
    final questionEdits = json['questionEdits'];
    if (questionEdits is Map<String, dynamic>) {
      for (final entry in questionEdits.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic> &&
            value['prompt'] is String &&
            value['answer'] is String) {
          result.questionEdits[entry.key] = (
            value['prompt'] as String,
            value['answer'] as String,
          );
        }
      }
    }
    final deleted = json['deletedQuestionIds'];
    if (deleted is List) {
      result.deletedQuestionIds.addAll([
        for (final id in deleted)
          if (id is String) id,
      ]);
    }
    final topicEdits = json['topicEdits'];
    if (topicEdits is Map<String, dynamic>) {
      for (final entry in topicEdits.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic> &&
            value['title'] is String &&
            value['description'] is String) {
          result.topicEdits[entry.key] = (
            value['title'] as String,
            value['description'] as String,
          );
        }
      }
    }
    return result;
  }
}

InterviewTopic applyOverrides(
  InterviewTopic topic,
  CatalogOverrides overrides,
) {
  final topicEdit = overrides.topicEdits[topic.id];
  final questions = [
    for (final question in topic.questions)
      if (!overrides.deletedQuestionIds.contains(question.id))
        overrides.questionEdits.containsKey(question.id)
            ? InterviewQuestion(
                question.id,
                overrides.questionEdits[question.id]!.$1,
                overrides.questionEdits[question.id]!.$2,
              )
            : question,
  ];
  return InterviewTopic(
    topic.id,
    topicEdit?.$1 ?? topic.title,
    topicEdit?.$2 ?? topic.description,
    questions,
  );
}

InterviewTopic? userTopicFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final title = json['title'];
  final questions = json['questions'];
  if (id is! String || title is! String || questions is! List) return null;
  final parsed = questions
      .map((question) {
        if (question is! Map<String, dynamic>) return null;
        final questionId = question['id'];
        final prompt = question['prompt'];
        final answer = question['answer'];
        if (questionId is! String || prompt is! String || answer is! String) {
          return null;
        }
        return InterviewQuestion(questionId, prompt, answer);
      })
      .whereType<InterviewQuestion>()
      .toList();
  return InterviewTopic(
    id,
    title,
    json['description'] is String ? json['description'] as String : '',
    parsed,
  );
}

Map<String, dynamic> userTopicToJson(InterviewTopic topic) => {
  'id': topic.id,
  'title': topic.title,
  'description': topic.description,
  'questions': [
    for (final question in topic.questions)
      {'id': question.id, 'prompt': question.prompt, 'answer': question.answer},
  ],
};

InterviewQuestion? userQuestionFromJson(Map<String, dynamic> json) {
  final id = json['id'];
  final prompt = json['prompt'];
  final answer = json['answer'];
  if (id is! String || prompt is! String || answer is! String) return null;
  return InterviewQuestion(id, prompt, answer);
}

Map<String, dynamic> userQuestionToJson(InterviewQuestion question) => {
  'id': question.id,
  'prompt': question.prompt,
  'answer': question.answer,
};

typedef _ParsedQuestion = (String prompt, String answer);
typedef _ParsedTopic = ({
  String title,
  String description,
  List<_ParsedQuestion> questions,
});

/// Parses and fully validates an import payload before any catalog change.
/// Accepts the current `version: 1` schema with a non-empty `topics` list;
/// IDs from the input JSON are ignored, callers generate fresh ones.
List<_ParsedTopic> _parseImportTopics(String source) {
  final dynamic decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException {
    throw const FormatException('Invalid JSON');
  }
  if (decoded is! Map<String, dynamic> ||
      decoded['version'] != 1 ||
      decoded['topics'] is! List ||
      (decoded['topics'] as List).isEmpty) {
    throw const FormatException(
      'Expected version: 1 and a non-empty topics list',
    );
  }
  final parsed = <_ParsedTopic>[];
  for (final raw in decoded['topics'] as List) {
    if (raw is! Map<String, dynamic> ||
        raw['title'] is! String ||
        (raw['title'] as String).trim().isEmpty ||
        raw['description'] is! String ||
        raw['questions'] is! List) {
      throw const FormatException('Invalid topic');
    }
    final questions = <_ParsedQuestion>[];
    for (final q in raw['questions'] as List) {
      if (q is! Map<String, dynamic> ||
          q['prompt'] is! String ||
          (q['prompt'] as String).trim().isEmpty ||
          q['answer'] is! String ||
          (q['answer'] as String).trim().isEmpty) {
        throw const FormatException(
          'Each question must have a prompt and answer',
        );
      }
      questions.add((
        (q['prompt'] as String).trim(),
        (q['answer'] as String).trim(),
      ));
    }
    parsed.add((
      title: (raw['title'] as String).trim(),
      description: raw['description'] as String,
      questions: questions,
    ));
  }
  return parsed;
}

const _uuid = Uuid();

class TopicCatalog extends ChangeNotifier {
  TopicCatalog({
    UserTopicsRepository? userTopicsRepository,
    List<InterviewTopic>? baseTopics,
  }) : _userTopics = userTopicsRepository,
       _baseTopics = baseTopics ?? questionCatalog;

  final UserTopicsRepository? _userTopics;
  final List<InterviewTopic> _baseTopics;
  List<InterviewTopic> _userList = [];
  final Map<String, List<InterviewQuestion>> _extraQuestions = {};
  CatalogOverrides _overrides = CatalogOverrides();
  Future<void> _pendingMutation = Future<void>.value();

  Future<T> _enqueueMutation<T>(Future<T> Function() mutation) {
    final result = _pendingMutation.then((_) => mutation());
    _pendingMutation = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stackTrace) {},
    );
    return result;
  }

  List<InterviewTopic> get topics => [
    for (final topic in _baseTopics)
      if (topic.questions.any(
            (q) => !_overrides.deletedQuestionIds.contains(q.id),
          ) ||
          (_extraQuestions[topic.id]?.isNotEmpty ?? false))
        applyOverrides(_withExtra(topic), _overrides),
    ...[
      for (final topic in _userList)
        applyOverrides(_withExtra(topic), _overrides),
    ],
  ];

  InterviewTopic? topicById(String id) {
    for (final topic in topics) {
      if (topic.id == id) return topic;
    }
    return null;
  }

  bool hasTitle(String title) => _visibleTopicByTitle(title) != null;

  InterviewTopic? _visibleTopicByTitle(String title) {
    final clean = title.trim().toLowerCase();
    for (final topic in topics) {
      if (topic.title.toLowerCase() == clean) return topic;
    }
    return null;
  }

  Set<String> get knownQuestionIds => {
    for (final topic in topics) ...[
      for (final question in topic.questions) question.id,
    ],
  };

  Future<InterviewTopic> addUserTopic(
    String title,
    String description,
    List<(String prompt, String answer)> questions,
  ) => _enqueueMutation(() async {
    final uniqueTitle = _uniqueTitle(title);
    final topicId = _uuid.v4();
    final added = InterviewTopic(
      topicId,
      uniqueTitle.trim(),
      description.trim(),
      [
        for (final (prompt, answer) in questions)
          InterviewQuestion(_uuid.v4(), prompt, answer),
      ],
    );
    final updated = [..._userList, added];
    await _persistUserTopics(updated);
    _userList = updated;
    notifyListeners();
    return added;
  });

  Future<void> addQuestionsToTopic(
    String topicId,
    List<(String prompt, String answer)> questions,
  ) => _enqueueMutation(() async {
    final topic = topicById(topicId);
    if (topic == null) {
      throw ArgumentError.value(topicId, 'topicId', 'Topic not found');
    }
    final appended = [
      for (final (prompt, answer) in questions)
        InterviewQuestion(_uuid.v4(), prompt, answer),
    ];
    final index = _userList.indexWhere((t) => t.id == topicId);
    if (index >= 0) {
      final updated = [..._userList];
      updated[index] = InterviewTopic(
        topic.id,
        topic.title,
        topic.description,
        [...topic.questions, ...appended],
      );
      await _persistUserTopics(updated);
      _userList = updated;
    } else {
      final updated = {
        ..._extraQuestions,
        topicId: [...?_extraQuestions[topicId], ...appended],
      };
      await _persistExtraQuestions(updated);
      _extraQuestions
        ..clear()
        ..addAll(updated);
    }
    notifyListeners();
  });

  Future<void> updateQuestion(
    String questionId,
    String prompt,
    String answer,
  ) => _enqueueMutation(() async {
    final question = topicById(_questionOwner(questionId))?.questions
        .where((q) => q.id == questionId)
        .firstOrNull;
    if (question == null) {
      throw ArgumentError.value(questionId, 'questionId', 'Question not found');
    }
    final trimmedPrompt = prompt.trim();
    final trimmedAnswer = answer.trim();
    final isBuiltin = _userList.every(
      (topic) => topic.questions.every((q) => q.id != questionId),
    );
    if (isBuiltin) {
      final updated = CatalogOverrides.fromJson(_overrides.toJson());
      if (_matchesBuiltin(questionId, trimmedPrompt, trimmedAnswer)) {
        updated.questionEdits.remove(questionId);
      } else {
        updated.questionEdits[questionId] = (trimmedPrompt, trimmedAnswer);
      }
      await _persistOverrides(updated);
      _overrides = updated;
    } else {
      final index = _userList.indexWhere(
        (topic) => topic.questions.any((q) => q.id == questionId),
      );
      final stored = _userList[index];
      final updated = [..._userList];
      updated[index] = InterviewTopic(
        stored.id,
        stored.title,
        stored.description,
        [
          for (final q in stored.questions)
            q.id == questionId
                ? InterviewQuestion(q.id, trimmedPrompt, trimmedAnswer)
                : q,
        ],
      );
      await _persistUserTopics(updated);
      _userList = updated;
    }
    notifyListeners();
  });

  bool _matchesBuiltin(String questionId, String prompt, String answer) {
    for (final topic in _baseTopics) {
      for (final question in topic.questions) {
        if (question.id == questionId) {
          return question.prompt == prompt && question.answer == answer;
        }
      }
    }
    return false;
  }

  Future<void> deleteQuestion(String questionId) => _enqueueMutation(() async {
    final isBuiltin = _userList.every(
      (topic) => topic.questions.every((q) => q.id != questionId),
    );
    if (isBuiltin) {
      final updated = CatalogOverrides.fromJson(_overrides.toJson());
      updated.deletedQuestionIds.add(questionId);
      await _persistOverrides(updated);
      _overrides = updated;
    } else {
      final index = _userList.indexWhere(
        (topic) => topic.questions.any((q) => q.id == questionId),
      );
      final stored = _userList[index];
      final updated = [..._userList];
      updated[index] = InterviewTopic(
        stored.id,
        stored.title,
        stored.description,
        [
          for (final q in stored.questions)
            if (q.id != questionId) q,
        ],
      );
      await _persistUserTopics(updated);
      _userList = updated;
    }
    notifyListeners();
  });

  Future<void> updateTopicMeta(
    String topicId,
    String title,
    String description,
  ) => _enqueueMutation(() async {
    final index = _userList.indexWhere((t) => t.id == topicId);
    if (index >= 0) {
      final stored = _userList[index];
      final updated = [..._userList];
      updated[index] = InterviewTopic(
        stored.id,
        title.trim(),
        description.trim(),
        stored.questions,
      );
      await _persistUserTopics(updated);
      _userList = updated;
    } else {
      final updated = CatalogOverrides.fromJson(_overrides.toJson());
      updated.topicEdits[topicId] = (title.trim(), description.trim());
      await _persistOverrides(updated);
      _overrides = updated;
    }
    notifyListeners();
  });

  String _uniqueTitle(String title) {
    final clean = title.trim();
    if (!hasTitle(clean)) return clean;
    var n = 2;
    while (hasTitle('$clean ($n)')) {
      n += 1;
    }
    return '$clean ($n)';
  }

  String _questionOwner(String questionId) {
    for (final topic in topics) {
      if (topic.questions.any((q) => q.id == questionId)) return topic.id;
    }
    return questionId;
  }

  InterviewTopic _withExtra(InterviewTopic topic) {
    final extra = _extraQuestions[topic.id];
    if (extra == null || extra.isEmpty) return topic;
    return InterviewTopic(topic.id, topic.title, topic.description, [
      ...topic.questions,
      ...extra,
    ]);
  }

  Future<void> _persistUserTopics(List<InterviewTopic> topics) async {
    final repository = _userTopics;
    if (repository == null) return;
    await repository.save([for (final topic in topics) userTopicToJson(topic)]);
  }

  Future<void> _persistExtraQuestions(
    Map<String, List<InterviewQuestion>> extraQuestions,
  ) async {
    final repository = _userTopics;
    if (repository == null) return;
    await repository.saveExtra({
      for (final entry in extraQuestions.entries)
        entry.key: [
          for (final question in entry.value) userQuestionToJson(question),
        ],
    });
  }

  Future<void> _persistOverrides(CatalogOverrides overrides) async {
    final repository = _userTopics;
    if (repository == null) return;
    await repository.saveOverrides(overrides.toJson());
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'version': 1,
    'topics': [for (final topic in topics) userTopicToJson(topic)],
  });

  Future<void> importJson(String source) => _enqueueMutation(() async {
    final parsedTopics = _parseImportTopics(source);
    final imported = [
      for (final parsed in parsedTopics)
        InterviewTopic(_uuid.v4(), parsed.title, parsed.description, [
          for (final (prompt, answer) in parsed.questions)
            InterviewQuestion(_uuid.v4(), prompt, answer),
        ]),
    ];
    final repository = _userTopics;
    final overrides = CatalogOverrides(
      deletedQuestionIds: {
        for (final topic in _baseTopics)
          for (final question in topic.questions) question.id,
      },
    );
    if (repository != null) {
      await repository.save([
        for (final topic in imported) userTopicToJson(topic),
      ]);
      await repository.saveExtra({});
      await repository.saveOverrides(overrides.toJson());
    }
    _userList = imported;
    _extraQuestions.clear();
    _overrides = overrides;
    notifyListeners();
  });

  /// Adds topics from an import payload without replacing existing data:
  /// topics matching a visible topic by title (trimmed, case-insensitive)
  /// get their questions appended; other topics are created as user topics.
  /// Extras, overrides, built-in topics and existing IDs stay untouched.
  /// The whole payload is validated before any change is applied.
  Future<void> addJson(String source) async {
    final parsedTopics = _parseImportTopics(source);
    for (final parsed in parsedTopics) {
      final existing = _visibleTopicByTitle(parsed.title);
      if (existing == null) {
        await addUserTopic(parsed.title, parsed.description, parsed.questions);
      } else {
        await addQuestionsToTopic(existing.id, parsed.questions);
      }
    }
  }

  Future<void> reset() => _enqueueMutation(() async {
    final repository = _userTopics;
    if (repository != null) {
      await repository.saveOverrides({});
      await repository.saveExtra({});
      await repository.save([]);
    }
    _userList = [];
    _extraQuestions.clear();
    _overrides = CatalogOverrides();
    notifyListeners();
  });

  Future<void> load() => _enqueueMutation(() async {
    final repository = _userTopics;
    if (repository == null) return;
    try {
      final loadedTopics = [
        for (final raw in await repository.load())
          if (userTopicFromJson(raw) case final InterviewTopic topic) topic,
      ];
      final loadedExtra = {
        for (final entry in (await repository.loadExtra()).entries)
          entry.key: [
            for (final question in entry.value)
              if (userQuestionFromJson(question) case final InterviewQuestion q)
                q,
          ],
      };
      final loadedOverrides = CatalogOverrides.fromJson(
        await repository.loadOverrides(),
      );
      _userList = loadedTopics;
      _extraQuestions
        ..clear()
        ..addAll(loadedExtra);
      _overrides = loadedOverrides;
      notifyListeners();
    } on Exception {
      // A read failure must not discard topics already loaded in memory.
    }
  });
}
