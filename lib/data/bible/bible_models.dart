import 'package:equatable/equatable.dart';

/// Versões exibidas na UI. Textos licenciados entram via plug-in (ver docs/BIBLIA.md).
enum BibleVersion {
  ara2(
    id: 'ara2',
    label: '2ª edição ARA revista e corrigida',
    shortLabel: 'ARA 2ª',
  ),
  ra(
    id: 'ra',
    label: 'Revista e atualizada (RA)',
    shortLabel: 'RA',
  ),
  sbb(
    id: 'sbb',
    label: 'SBB',
    shortLabel: 'SBB',
  ),
  ntlh(
    id: 'ntlh',
    label: 'Versão com linguagem de hoje (NTLH)',
    shortLabel: 'NTLH',
  );

  const BibleVersion({
    required this.id,
    required this.label,
    required this.shortLabel,
  });

  final String id;
  final String label;
  final String shortLabel;

  static BibleVersion fromId(String id) =>
      BibleVersion.values.firstWhere((v) => v.id == id, orElse: () => ara2);
}

class BibleBook {
  const BibleBook({
    required this.id,
    required this.name,
    required this.testament,
    required this.chapters,
  });

  final String id;
  final String name;
  final String testament; // 'AT' | 'NT'
  final int chapters;
}

class BibleVerse extends Equatable {
  const BibleVerse({
    required this.bookId,
    required this.chapter,
    required this.number,
    required this.text,
  });

  final String bookId;
  final int chapter;
  final int number;
  final String text;

  String get ref => '$bookId $chapter:$number';

  @override
  List<Object?> get props => [bookId, chapter, number, text];
}

class BibleChapter {
  const BibleChapter({
    required this.bookId,
    required this.chapter,
    required this.verses,
    this.sourceNote,
  });

  final String bookId;
  final int chapter;
  final List<BibleVerse> verses;
  final String? sourceNote;
}

class BibleBookmark extends Equatable {
  const BibleBookmark({
    required this.id,
    required this.versionId,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.createdAt,
    this.note,
    this.colorHex,
  });

  final String id;
  final String versionId;
  final String bookId;
  final int chapter;
  final int verse;
  final DateTime createdAt;
  final String? note;
  final String? colorHex;

  String get ref => '$bookId $chapter:$verse';

  Map<String, dynamic> toJson() => {
        'id': id,
        'versionId': versionId,
        'bookId': bookId,
        'chapter': chapter,
        'verse': verse,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'colorHex': colorHex,
      };

  factory BibleBookmark.fromJson(Map<String, dynamic> j) => BibleBookmark(
        id: j['id'] as String,
        versionId: j['versionId'] as String? ?? 'ara2',
        bookId: j['bookId'] as String,
        chapter: j['chapter'] as int,
        verse: j['verse'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        note: j['note'] as String?,
        colorHex: j['colorHex'] as String?,
      );

  @override
  List<Object?> get props => [id];
}

class BibleHighlight extends Equatable {
  const BibleHighlight({
    required this.id,
    required this.versionId,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.colorHex,
    required this.createdAt,
  });

  final String id;
  final String versionId;
  final String bookId;
  final int chapter;
  final int verse;
  final String colorHex;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'versionId': versionId,
        'bookId': bookId,
        'chapter': chapter,
        'verse': verse,
        'colorHex': colorHex,
        'createdAt': createdAt.toIso8601String(),
      };

  factory BibleHighlight.fromJson(Map<String, dynamic> j) => BibleHighlight(
        id: j['id'] as String,
        versionId: j['versionId'] as String? ?? 'ara2',
        bookId: j['bookId'] as String,
        chapter: j['chapter'] as int,
        verse: j['verse'] as int,
        colorHex: j['colorHex'] as String? ?? '#B8892B',
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  @override
  List<Object?> get props => [id];
}

class ReadingPlanDay {
  const ReadingPlanDay({
    required this.day,
    required this.bookId,
    required this.chapter,
    this.title,
  });

  final int day;
  final String bookId;
  final int chapter;
  final String? title;

  Map<String, dynamic> toJson() => {
        'day': day,
        'bookId': bookId,
        'chapter': chapter,
        'title': title,
      };

  factory ReadingPlanDay.fromJson(Map<String, dynamic> j) => ReadingPlanDay(
        day: j['day'] as int,
        bookId: j['bookId'] as String,
        chapter: j['chapter'] as int,
        title: j['title'] as String?,
      );
}

class ReadingPlan {
  const ReadingPlan({
    required this.id,
    required this.title,
    required this.description,
    required this.days,
  });

  final String id;
  final String title;
  final String description;
  final List<ReadingPlanDay> days;
}

class ReadingPlanProgress {
  const ReadingPlanProgress({
    required this.planId,
    required this.completedDays,
    this.startedAt,
  });

  final String planId;
  final Set<int> completedDays;
  final DateTime? startedAt;

  Map<String, dynamic> toJson() => {
        'planId': planId,
        'completedDays': completedDays.toList()..sort(),
        'startedAt': startedAt?.toIso8601String(),
      };

  factory ReadingPlanProgress.fromJson(Map<String, dynamic> j) =>
      ReadingPlanProgress(
        planId: j['planId'] as String,
        completedDays: {
          for (final d in (j['completedDays'] as List? ?? const []))
            d as int,
        },
        startedAt: j['startedAt'] != null
            ? DateTime.parse(j['startedAt'] as String)
            : null,
      );
}

class BiblePrefs {
  const BiblePrefs({
    this.versionId = 'ara2',
    this.fontSize = 18,
    this.lastBookId = 'joao',
    this.lastChapter = 1,
  });

  final String versionId;
  final double fontSize;
  final String lastBookId;
  final int lastChapter;

  BiblePrefs copyWith({
    String? versionId,
    double? fontSize,
    String? lastBookId,
    int? lastChapter,
  }) =>
      BiblePrefs(
        versionId: versionId ?? this.versionId,
        fontSize: fontSize ?? this.fontSize,
        lastBookId: lastBookId ?? this.lastBookId,
        lastChapter: lastChapter ?? this.lastChapter,
      );

  Map<String, dynamic> toJson() => {
        'versionId': versionId,
        'fontSize': fontSize,
        'lastBookId': lastBookId,
        'lastChapter': lastChapter,
      };

  factory BiblePrefs.fromJson(Map<String, dynamic> j) => BiblePrefs(
        versionId: j['versionId'] as String? ?? 'ara2',
        fontSize: (j['fontSize'] as num?)?.toDouble() ?? 18,
        lastBookId: j['lastBookId'] as String? ?? 'joao',
        lastChapter: j['lastChapter'] as int? ?? 1,
      );
}
