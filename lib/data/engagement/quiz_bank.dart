import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:livro_registro/data/engagement/engagement_models.dart';

/// Resultado de uma seleção de rodada do quiz.
class QuizPickResult {
  const QuizPickResult({
    required this.questions,
    required this.poolSize,
    required this.requestedCount,
  });

  final List<QuizQuestion> questions;
  final int poolSize;
  final int requestedCount;

  bool get usedFullPool => poolSize > 0 && questions.length < requestedCount;
}

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

  int availableCount({
    required QuizLevel level,
    Set<String>? bookIds,
  }) =>
      filter(level: level, bookIds: bookIds).length;

  /// Seleciona perguntas aleatórias sem repetir na rodada, embaralha alternativas.
  QuizPickResult pickRound({
    required QuizLevel level,
    Set<String>? bookIds,
    int count = 10,
    Random? random,
  }) {
    final rng = random ?? Random();
    final pool = filter(level: level, bookIds: bookIds)..shuffle(rng);
    if (pool.isEmpty) {
      return QuizPickResult(
        questions: const [],
        poolSize: 0,
        requestedCount: count,
      );
    }
    final take = count.clamp(1, pool.length);
    final picked = pool
        .take(take)
        .map((q) => q.withShuffledOptions(rng))
        .toList();
    return QuizPickResult(
      questions: picked,
      poolSize: pool.length,
      requestedCount: count,
    );
  }

  /// Mantido por compatibilidade; prefira [pickRound].
  List<QuizQuestion> pick({
    required QuizLevel level,
    Set<String>? bookIds,
    int count = 10,
    Random? random,
  }) =>
      pickRound(
        level: level,
        bookIds: bookIds,
        count: count,
        random: random,
      ).questions;

  Set<String> get bookIds => {for (final q in questions) q.bookId};
}
