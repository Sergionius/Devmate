import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/question.dart';
import 'question_catalog.dart';

/// Хранилище пользовательского контента поверх компилируемого каталога.
abstract class UserTopicsRepository {
  /// Новые темы, созданные пользователем/моделью.
  Future<List<Map<String, dynamic>>> load();

  Future<void> save(List<Map<String, dynamic>> topics);

  /// Вопросы, добавленные пользователем в существующие темы:
  /// topicId → список вопросов (raw JSON).
  Future<Map<String, List<Map<String, dynamic>>>> loadExtra();

  Future<void> saveExtra(Map<String, List<Map<String, dynamic>>> extra);

  /// Оверлеи правок над компилируемым контентом: правки вопросов
  /// (qId → {prompt, answer}), удалённые вопросы, правки метаданных тем.
  Future<Map<String, dynamic>> loadOverrides();

  Future<void> saveOverrides(Map<String, dynamic> overrides);
}

/// Реализация поверх SharedPreferences: по одному JSON-ключу на сущность.
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

/// Оверлеи правок над встроенным контентом.
class CatalogOverrides {
  CatalogOverrides({
    Map<String, (String, String)>? questionEdits,
    Set<String>? deletedQuestionIds,
    Map<String, (String, String)>? topicEdits,
  }) : questionEdits = questionEdits ?? {},
       deletedQuestionIds = deletedQuestionIds ?? {},
       topicEdits = topicEdits ?? {};

  /// questionId → (prompt, answer): правки существующих вопросов,
  /// включая встроенные.
  final Map<String, (String, String)> questionEdits;
  final Set<String> deletedQuestionIds;

  /// topicId → (title, description): правки названия/описания темы.
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

/// Применяет оверлеи к теме: правки/удаления вопросов и метаданных.
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
  if (parsed.isEmpty) return null;
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

const _uuid = Uuid();

/// Объединённый каталог: компилируемая база + оверлеи правок +
/// пользовательские темы и доп. вопросы. Всё изменяемо.
/// Слушатели уведомляются при изменениях.
class TopicCatalog extends ChangeNotifier {
  TopicCatalog({UserTopicsRepository? userTopicsRepository})
    : _userTopics = userTopicsRepository;

  final UserTopicsRepository? _userTopics;
  List<InterviewTopic> _userList = [];
  final Map<String, List<InterviewQuestion>> _extraQuestions = {};
  CatalogOverrides _overrides = CatalogOverrides();

  /// Компилируемая база + пользовательские темы, с применёнными оверлеями.
  List<InterviewTopic> get topics => [
    for (final topic in questionCatalog)
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

  bool hasTitle(String title) => topics.any(
    (topic) => topic.title.toLowerCase() == title.trim().toLowerCase(),
  );

  /// Все существующие id вопросов (для чистки прогресса от мусора).
  Set<String> get knownQuestionIds => {
    for (final topic in topics) ...[
      for (final question in topic.questions) question.id,
    ],
  };

  /// Новая пользовательская тема. Все id — UUID v4.
  Future<InterviewTopic> addUserTopic(
    String title,
    String description,
    List<(String prompt, String answer)> questions,
  ) async {
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
    _userList = [..._userList, added];
    await _persistUserTopics();
    notifyListeners();
    return added;
  }

  /// Вопросы в существующую тему (встроенную или пользовательскую).
  Future<void> addQuestionsToTopic(
    String topicId,
    List<(String prompt, String answer)> questions,
  ) async {
    final topic = topicById(topicId);
    if (topic == null) {
      throw ArgumentError.value(topicId, 'topicId', 'Тема не найдена');
    }
    final appended = [
      for (final (prompt, answer) in questions)
        InterviewQuestion(_uuid.v4(), prompt, answer),
    ];
    final index = _userList.indexWhere((t) => t.id == topicId);
    if (index >= 0) {
      // Пользовательская тема хранится целиком: дописываем к текущим
      // вопросам (topic уже включает прежние extra) и НЕ трогаем extras map,
      // иначе _withExtra задублирует вопросы.
      _userList[index] = InterviewTopic(
        topic.id,
        topic.title,
        topic.description,
        [...topic.questions, ...appended],
      );
      await _persistUserTopics();
    } else {
      // Встроенная тема неизменяемая — доп. вопросы хранятся отдельно.
      _extraQuestions[topicId] = [...?_extraQuestions[topicId], ...appended];
      await _persistExtraQuestions();
    }
    notifyListeners();
  }

  /// Правка вопроса (prompt и/или answer) — работает и для встроенных
  /// вопросов (через оверлей), и для пользовательских (прямая правка).
  Future<void> updateQuestion(
    String questionId,
    String prompt,
    String answer,
  ) async {
    final question = topicById(_questionOwner(questionId))?.questions
        .where((q) => q.id == questionId)
        .firstOrNull;
    if (question == null) {
      throw ArgumentError.value(questionId, 'questionId', 'Вопрос не найден');
    }
    final trimmedPrompt = prompt.trim();
    final trimmedAnswer = answer.trim();
    final isBuiltin = _userList.every(
      (topic) => topic.questions.every((q) => q.id != questionId),
    );
    if (isBuiltin) {
      // Встроенный вопрос: правим оверлеем. Возврат к компилируемому тексту
      // снимает оверлей.
      if (_matchesBuiltin(questionId, trimmedPrompt, trimmedAnswer)) {
        _overrides.questionEdits.remove(questionId);
      } else {
        _overrides.questionEdits[questionId] = (trimmedPrompt, trimmedAnswer);
      }
      await _persistOverrides();
    } else {
      // Пользовательский вопрос: правим прямо в хранимой теме.
      final index = _userList.indexWhere(
        (topic) => topic.questions.any((q) => q.id == questionId),
      );
      final stored = _userList[index];
      _userList[index] = InterviewTopic(
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
      await _persistUserTopics();
    }
    notifyListeners();
  }

  /// Совпадает ли текст вопроса с компилируемой базой.
  bool _matchesBuiltin(String questionId, String prompt, String answer) {
    for (final topic in questionCatalog) {
      for (final question in topic.questions) {
        if (question.id == questionId) {
          return question.prompt == prompt && question.answer == answer;
        }
      }
    }
    return false;
  }

  /// Удаление вопроса (оверей-удаление для встроенных, прямое для
  /// пользовательских).
  Future<void> deleteQuestion(String questionId) async {
    final isBuiltin = _userList.every(
      (topic) => topic.questions.every((q) => q.id != questionId),
    );
    if (isBuiltin) {
      _overrides.deletedQuestionIds.add(questionId);
      await _persistOverrides();
    } else {
      final index = _userList.indexWhere(
        (topic) => topic.questions.any((q) => q.id == questionId),
      );
      final stored = _userList[index];
      _userList[index] = InterviewTopic(
        stored.id,
        stored.title,
        stored.description,
        [
          for (final q in stored.questions)
            if (q.id != questionId) q,
        ],
      );
      await _persistUserTopics();
    }
    notifyListeners();
  }

  /// Правка названия/описания темы (оверей для встроенных, прямая для
  /// пользовательских).
  Future<void> updateTopicMeta(
    String topicId,
    String title,
    String description,
  ) async {
    final index = _userList.indexWhere((t) => t.id == topicId);
    if (index >= 0) {
      final stored = _userList[index];
      _userList[index] = InterviewTopic(
        stored.id,
        title.trim(),
        description.trim(),
        stored.questions,
      );
      await _persistUserTopics();
    } else {
      _overrides.topicEdits[topicId] = (title.trim(), description.trim());
      await _persistOverrides();
    }
    notifyListeners();
  }

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

  Future<void> _persistUserTopics() async {
    final repository = _userTopics;
    if (repository == null) return;
    await repository.save([
      for (final topic in _userList) userTopicToJson(topic),
    ]);
  }

  Future<void> _persistExtraQuestions() async {
    final repository = _userTopics;
    if (repository == null) return;
    await repository.saveExtra({
      for (final entry in _extraQuestions.entries)
        entry.key: [
          for (final question in entry.value) userQuestionToJson(question),
        ],
    });
  }

  Future<void> _persistOverrides() async {
    final repository = _userTopics;
    if (repository == null) return;
    await repository.saveOverrides(_overrides.toJson());
  }

  /// Загружает пользовательский контент; ошибки хранения не роняют
  /// приложение.
  Future<void> load() async {
    final repository = _userTopics;
    if (repository == null) return;
    try {
      _userList = [
        for (final raw in await repository.load())
          if (userTopicFromJson(raw) case final InterviewTopic topic) topic,
      ];
      _extraQuestions
        ..clear()
        ..addAll({
          for (final entry in (await repository.loadExtra()).entries)
            entry.key: [
              for (final question in entry.value)
                if (userQuestionFromJson(question)
                    case final InterviewQuestion q)
                  q,
            ],
        });
      _overrides = CatalogOverrides.fromJson(await repository.loadOverrides());
    } on Exception {
      _userList = [];
      _extraQuestions.clear();
      _overrides = CatalogOverrides();
    }
    notifyListeners();
  }
}
