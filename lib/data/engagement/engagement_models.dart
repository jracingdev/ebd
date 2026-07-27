import 'package:equatable/equatable.dart';

/// Critérios combináveis do sorteio EBD.
class RaffleCriteria extends Equatable {
  const RaffleCriteria({
    this.onlyPresentOnDate = false,
    this.attendanceDate,
    this.onlyMagazinePaid = false,
    this.onlyMagazinePending = false,
    this.onlyBirthdayMonth = false,
    this.excludePreviousWinners = true,
    this.requireMatriculaOrPhone = false,
    this.excludeTeachers = true,
    this.winnerCount = 1,
    this.onePerClass = false,
  });

  /// Filtra quem esteve presente na data (padrão: último domingo).
  final bool onlyPresentOnDate;
  final String? attendanceDate;

  final bool onlyMagazinePaid;
  final bool onlyMagazinePending;
  final bool onlyBirthdayMonth;
  final bool excludePreviousWinners;

  /// Cadastro com matrícula ou telefone preenchido.
  final bool requireMatriculaOrPhone;

  /// Remove nomes que coincidem com usuários staff/professores.
  final bool excludeTeachers;

  final int winnerCount;
  final bool onePerClass;

  RaffleCriteria copyWith({
    bool? onlyPresentOnDate,
    String? attendanceDate,
    bool? onlyMagazinePaid,
    bool? onlyMagazinePending,
    bool? onlyBirthdayMonth,
    bool? excludePreviousWinners,
    bool? requireMatriculaOrPhone,
    bool? excludeTeachers,
    int? winnerCount,
    bool? onePerClass,
  }) =>
      RaffleCriteria(
        onlyPresentOnDate: onlyPresentOnDate ?? this.onlyPresentOnDate,
        attendanceDate: attendanceDate ?? this.attendanceDate,
        onlyMagazinePaid: onlyMagazinePaid ?? this.onlyMagazinePaid,
        onlyMagazinePending: onlyMagazinePending ?? this.onlyMagazinePending,
        onlyBirthdayMonth: onlyBirthdayMonth ?? this.onlyBirthdayMonth,
        excludePreviousWinners:
            excludePreviousWinners ?? this.excludePreviousWinners,
        requireMatriculaOrPhone:
            requireMatriculaOrPhone ?? this.requireMatriculaOrPhone,
        excludeTeachers: excludeTeachers ?? this.excludeTeachers,
        winnerCount: winnerCount ?? this.winnerCount,
        onePerClass: onePerClass ?? this.onePerClass,
      );

  Map<String, dynamic> toJson() => {
        'onlyPresentOnDate': onlyPresentOnDate,
        'attendanceDate': attendanceDate,
        'onlyMagazinePaid': onlyMagazinePaid,
        'onlyMagazinePending': onlyMagazinePending,
        'onlyBirthdayMonth': onlyBirthdayMonth,
        'excludePreviousWinners': excludePreviousWinners,
        'requireMatriculaOrPhone': requireMatriculaOrPhone,
        'excludeTeachers': excludeTeachers,
        'winnerCount': winnerCount,
        'onePerClass': onePerClass,
      };

  factory RaffleCriteria.fromJson(Map<String, dynamic> j) => RaffleCriteria(
        onlyPresentOnDate: j['onlyPresentOnDate'] as bool? ?? false,
        attendanceDate: j['attendanceDate'] as String?,
        onlyMagazinePaid: j['onlyMagazinePaid'] as bool? ?? false,
        onlyMagazinePending: j['onlyMagazinePending'] as bool? ?? false,
        onlyBirthdayMonth: j['onlyBirthdayMonth'] as bool? ?? false,
        excludePreviousWinners: j['excludePreviousWinners'] as bool? ?? true,
        requireMatriculaOrPhone: j['requireMatriculaOrPhone'] as bool? ?? false,
        excludeTeachers: j['excludeTeachers'] as bool? ?? true,
        winnerCount: (j['winnerCount'] as num?)?.toInt() ?? 1,
        onePerClass: j['onePerClass'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [
        onlyPresentOnDate,
        attendanceDate,
        onlyMagazinePaid,
        onlyMagazinePending,
        onlyBirthdayMonth,
        excludePreviousWinners,
        requireMatriculaOrPhone,
        excludeTeachers,
        winnerCount,
        onePerClass,
      ];
}

class RaffleWinner extends Equatable {
  const RaffleWinner({
    required this.studentId,
    required this.nome,
    required this.grupo,
  });

  final String studentId;
  final String nome;
  final String grupo;

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'nome': nome,
        'grupo': grupo,
      };

  factory RaffleWinner.fromJson(Map<String, dynamic> j) => RaffleWinner(
        studentId: j['studentId'] as String? ?? '',
        nome: j['nome'] as String? ?? '',
        grupo: j['grupo'] as String? ?? '',
      );

  @override
  List<Object?> get props => [studentId, nome, grupo];
}

class RaffleHistoryEntry extends Equatable {
  const RaffleHistoryEntry({
    required this.id,
    required this.at,
    required this.groups,
    required this.winners,
    required this.criteria,
    required this.trimestreKey,
  });

  final String id;
  final DateTime at;
  final List<String> groups;
  final List<RaffleWinner> winners;
  final RaffleCriteria criteria;
  final String trimestreKey;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'groups': groups,
        'winners': winners.map((e) => e.toJson()).toList(),
        'criteria': criteria.toJson(),
        'trimestreKey': trimestreKey,
      };

  factory RaffleHistoryEntry.fromJson(Map<String, dynamic> j) =>
      RaffleHistoryEntry(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        groups: (j['groups'] as List? ?? []).map((e) => e.toString()).toList(),
        winners: (j['winners'] as List? ?? [])
            .map((e) => RaffleWinner.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        criteria: RaffleCriteria.fromJson(
          Map<String, dynamic>.from(j['criteria'] as Map? ?? {}),
        ),
        trimestreKey: j['trimestreKey'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, at, groups, winners, criteria, trimestreKey];
}

enum QuizLevel { facil, medio, dificil, expert }

extension QuizLevelX on QuizLevel {
  String get label => switch (this) {
        QuizLevel.facil => 'Fácil',
        QuizLevel.medio => 'Médio',
        QuizLevel.dificil => 'Difícil',
        QuizLevel.expert => 'Expert',
      };

  String get id => name;

  static QuizLevel fromId(String? id) => QuizLevel.values.firstWhere(
        (e) => e.name == id,
        orElse: () => QuizLevel.facil,
      );
}

class QuizQuestion extends Equatable {
  const QuizQuestion({
    required this.id,
    required this.level,
    required this.bookId,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.reference,
  });

  final String id;
  final QuizLevel level;
  final String bookId;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String? reference;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        id: j['id'] as String,
        level: QuizLevelX.fromId(j['level'] as String?),
        bookId: j['bookId'] as String? ?? j['book'] as String? ?? 'gen',
        question: j['q'] as String? ?? j['question'] as String? ?? '',
        options: (j['options'] as List? ?? []).map((e) => e.toString()).toList(),
        correctIndex: (j['correct'] as num?)?.toInt() ?? 0,
        reference: j['ref'] as String? ?? j['reference'] as String?,
      );

  @override
  List<Object?> get props =>
      [id, level, bookId, question, options, correctIndex, reference];
}

class QuizBestScore extends Equatable {
  const QuizBestScore({
    required this.level,
    required this.score,
    required this.total,
    required this.at,
  });

  final QuizLevel level;
  final int score;
  final int total;
  final DateTime at;

  double get ratio => total == 0 ? 0 : score / total;

  Map<String, dynamic> toJson() => {
        'level': level.name,
        'score': score,
        'total': total,
        'at': at.toIso8601String(),
      };

  factory QuizBestScore.fromJson(Map<String, dynamic> j) => QuizBestScore(
        level: QuizLevelX.fromId(j['level'] as String?),
        score: (j['score'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        at: DateTime.tryParse(j['at']?.toString() ?? '') ?? DateTime.now(),
      );

  @override
  List<Object?> get props => [level, score, total, at];
}

/// Chave de trimestre civil: AAAA-Tn (T1=Jan-Mar … T4=Out-Dez).
String currentTrimestreKey([DateTime? now]) {
  final d = now ?? DateTime.now();
  final t = ((d.month - 1) ~/ 3) + 1;
  return '${d.year}-T$t';
}
