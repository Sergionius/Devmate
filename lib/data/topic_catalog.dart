import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/question.dart';
import 'question_catalog.dart';

/// Хранилище пользовательского контента; id с префиксом `u` не пересекаются
/// со встроенным каталогом.
abstract class UserTopicsRepository {
  Future<List<Map<String, dynamic>>> load();
  Future<void> save(List<Map<String, dynamic>> topics);

  /// Вопросы, добавленные пользователем в существующие темы:
  /// topicId → список вопросов (raw JSON).
  Future<Map<String, List<Map<String, dynamic>>>> loadExtra();
  Future<void> saveExtra(Map<String, List<Map<String, dynamic>>> extra);
}

/// Реализация поверх SharedPreferences: JSON-список тем под одним ключом.
class LocalUserTopicsRepository implements UserTopicsRepository {
  LocalUserTopicsRepository(this._preferences);

  static const _key = 'devmate.user_topics.v1';
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

  static const _extraKey = 'devmate.user_questions.v1';

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
}

/// Пользовательская тема, сгенерированная в чате. Хранится отдельно от
/// компилируемого каталога; id с префиксом `u` не пересекаются со встроенными.
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

/// Объединённый каталог: встроенные темы + пользовательские + добавленные
/// в любые темы вопросы. Слушатели уведомляются при изменениях.
class TopicCatalog extends ChangeNotifier {
  TopicCatalog({UserTopicsRepository? userTopicsRepository})
    : _userTopics = userTopicsRepository;

  final UserTopicsRepository? _userTopics;
  List<InterviewTopic> _userList = [];

  /// Вопросы, добавленные пользователем в существующие темы (в т.ч.
  /// встроенные): topicId → вопросы. Ключи и id уникальны глобально.
  final Map<String, List<InterviewQuestion>> _extraQuestions = {};

  /// Встроенные + пользовательские, с подмешанными доп. вопросами.
  List<InterviewTopic> get topics => [
    for (final topic in questionCatalog) _withExtra(topic),
    ...[for (final topic in _userList) _withExtra(topic)],
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

  /// Добавляет пользовательскую тему с уникальными id и персистит список.
  /// Повторяющееся название получает суффикс « (2)», « (3)»…
  Future<InterviewTopic> addUserTopic(
    String title,
    String description,
    List<(String prompt, String answer)> questions,
  ) async {
    final uniqueTitle = _uniqueTitle(title);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ids = _allocateIds(stamp, questions.length);
    final added = InterviewTopic(
      ids.topicId,
      uniqueTitle.trim(),
      description.trim(),
      [
        for (var i = 0; i < questions.length; i++)
          InterviewQuestion(
            ids.questionIds[i],
            questions[i].$1,
            questions[i].$2,
          ),
      ],
    );
    _userList = [..._userList, added];
    await _persistUserTopics();
    notifyListeners();
    return added;
  }

  /// Добавляет вопросы в существующую тему (встроенную или пользовательскую).
  Future<void> addQuestionsToTopic(
    String topicId,
    List<(String prompt, String answer)> questions,
  ) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ids = _allocateIds(stamp, questions.length);
    final appended = [
      for (var i = 0; i < questions.length; i++)
        InterviewQuestion(ids.questionIds[i], questions[i].$1, questions[i].$2),
    ];
    final topic = topicById(topicId);
    if (topic == null) {
      throw ArgumentError.value(topicId, 'topicId', 'Тема не найдена');
    }
    final index = _userList.indexWhere((t) => t.id == topicId);
    if (index >= 0) {
      // Пользовательская тема хранится целиком: дописываем к её текущим
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

  /// Уникальный id: если stamp уже занят (два действия за одну миллисекунду),
  /// увеличиваем до свободного. questionIds — «u{stamp}_q{i}».
  ({String topicId, List<String> questionIds}) _allocateIds(
    int stamp,
    int questionCount,
  ) {
    final taken = {
      for (final topic in topics) ...[
        topic.id,
        for (final question in topic.questions) question.id,
      ],
    };
    var candidate = stamp;
    bool allFree(int candidate) {
      if (taken.contains('u${candidate}_t0')) return false;
      for (var i = 0; i < questionCount; i++) {
        if (taken.contains('u${candidate}_q$i')) return false;
      }
      return true;
    }

    while (!allFree(candidate)) {
      candidate += 1;
    }
    final topicId = 'u${candidate}_t0';
    final questionIds = [
      for (var i = 0; i < questionCount; i++) 'u${candidate}_q$i',
    ];
    return (topicId: topicId, questionIds: questionIds);
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

  /// Загружает сохранённые темы и доп. вопросы; ошибки хранения не роняют
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
    } on Exception {
      _userList = [];
      _extraQuestions.clear();
    }
    notifyListeners();
  }
}

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
