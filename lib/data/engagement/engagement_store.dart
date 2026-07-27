import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:livro_registro/data/engagement/engagement_models.dart';

const _boxName = 'ebd_engagement_v1';
const _keyRaffles = 'raffle_history';
const _keyQuizBest = 'quiz_best';
const _keyPoints = 'gamification_points';
const _keyBadges = 'gamification_badges';

/// Persistência Hive de sorteios, quiz e placar.
class EngagementStore extends ChangeNotifier {
  EngagementStore(this._box);

  final Box _box;

  List<RaffleHistoryEntry> raffleHistory = [];
  Map<QuizLevel, QuizBestScore> quizBest = {};

  /// studentId → pontos acumulados.
  Map<String, int> pointsByStudent = {};

  /// studentId → ids de badges conquistados.
  Map<String, Set<String>> badgesByStudent = {};

  static Future<EngagementStore> open() async {
    final box = await Hive.openBox(_boxName);
    final store = EngagementStore(box);
    store.load();
    return store;
  }

  void load() {
    raffleHistory = _readList(_keyRaffles, RaffleHistoryEntry.fromJson)
      ..sort((a, b) => b.at.compareTo(a.at));
    quizBest = {};
    final rawQuiz = _box.get(_keyQuizBest);
    if (rawQuiz != null) {
      final map = rawQuiz is String ? jsonDecode(rawQuiz) : rawQuiz;
      if (map is Map) {
        for (final e in map.entries) {
          final level = QuizLevelX.fromId(e.key.toString());
          quizBest[level] = QuizBestScore.fromJson(
            Map<String, dynamic>.from(e.value as Map),
          );
        }
      }
    }
    pointsByStudent = {};
    final rawPts = _box.get(_keyPoints);
    if (rawPts != null) {
      final map = rawPts is String ? jsonDecode(rawPts) : rawPts;
      if (map is Map) {
        for (final e in map.entries) {
          pointsByStudent[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
        }
      }
    }
    badgesByStudent = {};
    final rawBadges = _box.get(_keyBadges);
    if (rawBadges != null) {
      final map = rawBadges is String ? jsonDecode(rawBadges) : rawBadges;
      if (map is Map) {
        for (final e in map.entries) {
          final list = e.value is List ? e.value as List : const [];
          badgesByStudent[e.key.toString()] = {
            for (final b in list) b.toString(),
          };
        }
      }
    }
    notifyListeners();
  }

  List<T> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _box.get(key);
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return [];
    return list
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addRaffle(RaffleHistoryEntry entry) async {
    raffleHistory = [entry, ...raffleHistory];
    await _box.put(
      _keyRaffles,
      jsonEncode(raffleHistory.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  Future<void> clearRaffleHistory() async {
    raffleHistory = [];
    await _box.put(_keyRaffles, jsonEncode([]));
    notifyListeners();
  }

  Set<String> winnerIdsInTrimestre(String trimestreKey) {
    final ids = <String>{};
    for (final e in raffleHistory) {
      if (e.trimestreKey != trimestreKey) continue;
      for (final w in e.winners) {
        if (w.studentId.isNotEmpty) ids.add(w.studentId);
      }
    }
    return ids;
  }

  Future<void> saveQuizBest(QuizBestScore score) async {
    final prev = quizBest[score.level];
    if (prev != null && prev.ratio > score.ratio) return;
    if (prev != null &&
        prev.ratio == score.ratio &&
        prev.score >= score.score) {
      return;
    }
    quizBest = {...quizBest, score.level: score};
    await _box.put(
      _keyQuizBest,
      jsonEncode({
        for (final e in quizBest.entries) e.key.name: e.value.toJson(),
      }),
    );
    notifyListeners();
  }

  Future<void> setPoints(String studentId, int points) async {
    pointsByStudent = {...pointsByStudent, studentId: points};
    await _persistPoints();
  }

  Future<void> addPoints(String studentId, int delta) async {
    final next = (pointsByStudent[studentId] ?? 0) + delta;
    pointsByStudent = {...pointsByStudent, studentId: next};
    await _persistPoints();
  }

  Future<void> replaceAllPoints(Map<String, int> map) async {
    pointsByStudent = Map<String, int>.from(map);
    await _persistPoints();
  }

  Future<void> _persistPoints() async {
    await _box.put(_keyPoints, jsonEncode(pointsByStudent));
    notifyListeners();
  }

  Future<void> unlockBadge(String studentId, String badgeId) async {
    final set = {...(badgesByStudent[studentId] ?? <String>{})};
    if (set.contains(badgeId)) return;
    set.add(badgeId);
    badgesByStudent = {...badgesByStudent, studentId: set};
    await _box.put(
      _keyBadges,
      jsonEncode({
        for (final e in badgesByStudent.entries) e.key: e.value.toList(),
      }),
    );
    notifyListeners();
  }

  Future<void> replaceAllBadges(Map<String, Set<String>> map) async {
    badgesByStudent = {
      for (final e in map.entries) e.key: {...e.value},
    };
    await _box.put(
      _keyBadges,
      jsonEncode({
        for (final e in badgesByStudent.entries) e.key: e.value.toList(),
      }),
    );
    notifyListeners();
  }

  Map<String, dynamic> exportMap() => {
        'raffle_history': raffleHistory.map((e) => e.toJson()).toList(),
        'quiz_best': {
          for (final e in quizBest.entries) e.key.name: e.value.toJson(),
        },
        'gamification_points': pointsByStudent,
        'gamification_badges': {
          for (final e in badgesByStudent.entries) e.key: e.value.toList(),
        },
      };

  Future<void> importMap(Map<String, dynamic> map) async {
    if (map['raffle_history'] is List) {
      raffleHistory = (map['raffle_history'] as List)
          .map(
            (e) => RaffleHistoryEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at));
      await _box.put(
        _keyRaffles,
        jsonEncode(raffleHistory.map((e) => e.toJson()).toList()),
      );
    }
    if (map['quiz_best'] is Map) {
      quizBest = {};
      for (final e in (map['quiz_best'] as Map).entries) {
        quizBest[QuizLevelX.fromId(e.key.toString())] = QuizBestScore.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        );
      }
      await _box.put(
        _keyQuizBest,
        jsonEncode({
          for (final e in quizBest.entries) e.key.name: e.value.toJson(),
        }),
      );
    }
    if (map['gamification_points'] is Map) {
      pointsByStudent = {
        for (final e in (map['gamification_points'] as Map).entries)
          e.key.toString(): (e.value as num?)?.toInt() ?? 0,
      };
      await _box.put(_keyPoints, jsonEncode(pointsByStudent));
    }
    if (map['gamification_badges'] is Map) {
      badgesByStudent = {
        for (final e in (map['gamification_badges'] as Map).entries)
          e.key.toString(): {
            for (final b in (e.value as List? ?? const [])) b.toString(),
          },
      };
      await _box.put(
        _keyBadges,
        jsonEncode({
          for (final e in badgesByStudent.entries) e.key: e.value.toList(),
        }),
      );
    }
    notifyListeners();
  }
}
