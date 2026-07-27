import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:livro_registro/data/engagement/engagement_models.dart';

/// Carrega o banco embutido `assets/quiz/questions.json`.
class QuizBank {
  QuizBank._(this.questions);

  final List<QuizQuestion> questions;

  static QuizBank? _instance;

  static Future<QuizBank> load() async {
    if (_instance != null) return _instance!;
    final raw = await rootBundle.loadString('assets/quiz/questions.json');
    final map = jsonDecode(raw) as Map<String, dynamic>;
    final list = (map['questions'] as List? ?? [])
        .map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((q) => q.question.isNotEmpty && q.options.length >= 2)
        .toList();
    _instance = QuizBank._(list);
    return _instance!;
  }

  List<QuizQuestion> filter({
    required QuizLevel level,
    Set<String>? bookIds,
  }) {
    return questions.where((q) {
      if (q.level != level) return false;
      if (bookIds != null && bookIds.isNotEmpty && !bookIds.contains(q.bookId)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<QuizQuestion> pick({
    required QuizLevel level,
    Set<String>? bookIds,
    int count = 10,
  }) {
    final pool = filter(level: level, bookIds: bookIds)..shuffle();
    if (pool.isEmpty) return [];
    return pool.take(count.clamp(1, pool.length)).toList();
  }

  Set<String> get bookIds => {for (final q in questions) q.bookId};
}
