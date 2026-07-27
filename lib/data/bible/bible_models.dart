import 'package:equatable/equatable.dart';

/// Versões exibidas na UI.
///
/// - [almeida1819]: texto completo embutido (domínio público).
/// - Demais: buscam texto completo via API (Midvash e/ou API.Bible) com cache offline.
///   Direitos das edições modernas pertencem aos detentores (ex. SBB); ver docs/BIBLIA.md.
enum BibleVersion {
  ara2(
    id: 'ara2',
    label: '2ª edição ARA revista e corrigida',
    shortLabel: 'ARA 2ª',
    remoteSlug: 'arc',
    delivery: BibleVersionDelivery.remoteApi,
    licenseSummary:
        'Edição moderna protegida. Texto servido via API pública (Midvash slug `arc` = Almeida Revista e Corrigida) com cache no aparelho. '
        'Para distribuição embutida ou API.Bible licenciada, configure BIBLE_API_KEY + BIBLE_API_ID_ARA2.',
  ),
  ra(
    id: 'ra',
    label: 'Revista e atualizada (RA)',
    shortLabel: 'RA',
    remoteSlug: 'ara',
    delivery: BibleVersionDelivery.remoteApi,
    licenseSummary:
        'ARA (Revista e Atualizada) protegida. Texto via API (Midvash `ara`) + cache. '
        'Pacote embutido exige contrato SBB; opcionalmente BIBLE_API_ID_RA no .env.',
  ),
  sbb(
    id: 'sbb',
    label: 'SBB (Nova Almeida Atualizada)',
    shortLabel: 'SBB',
    remoteSlug: 'naa',
    delivery: BibleVersionDelivery.remoteApi,
    licenseSummary:
        '“SBB” no app aponta para a NAA (Nova Almeida Atualizada, publicada pela SBB) via API Midvash `naa` + cache. '
        'Outras edições SBB exigem licença própria (BIBLE_API_ID_SBB).',
  ),
  ntlh(
    id: 'ntlh',
    label: 'Versão com linguagem de hoje (NTLH)',
    shortLabel: 'NTLH',
    remoteSlug: 'ntlh',
    delivery: BibleVersionDelivery.remoteApi,
    licenseSummary:
        'NTLH protegida (SBB). Texto via API Midvash `ntlh` + cache. '
        'Embutir no APK exige licença; opcional BIBLE_API_ID_NTLH.',
  ),
  almeida1819(
    id: 'almeida1819',
    label: 'Almeida 1819 (domínio público)',
    shortLabel: 'AL 1819',
    remoteSlug: null,
    delivery: BibleVersionDelivery.localAsset,
    licenseSummary:
        'Domínio público (João Ferreira de Almeida 1819 / Bíblia Livre). '
        'Texto completo embutido em assets/bible/almeida_1819.json — funciona 100% offline.',
  );

  const BibleVersion({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.remoteSlug,
    required this.delivery,
    required this.licenseSummary,
  });

  final String id;
  final String label;
  final String shortLabel;
  final String? remoteSlug;
  final BibleVersionDelivery delivery;
  final String licenseSummary;

  bool get isLocalAsset => delivery == BibleVersionDelivery.localAsset;
  bool get isRemote => delivery == BibleVersionDelivery.remoteApi;

  String get remoteSourceNote =>
      'Texto de $shortLabel via API pública (cache offline no aparelho). '
      'Edição protegida — ver docs/BIBLIA.md. Não extraído de APK de terceiros.';

  static BibleVersion fromId(String id) => BibleVersion.values.firstWhere(
        (v) => v.id == id,
        orElse: () => BibleVersion.almeida1819,
      );
}

enum BibleVersionDelivery { localAsset, remoteApi }

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

/// Estado quando o capítulo não pôde ser carregado (nunca “silêncio vazio”).
class BibleChapterLoad {
  const BibleChapterLoad.ok(this.chapter)
      : errorMessage = null,
        canRetry = false;

  const BibleChapterLoad.fail({
    required this.errorMessage,
    this.canRetry = true,
  }) : chapter = null;

  final BibleChapter? chapter;
  final String? errorMessage;
  final bool canRetry;

  bool get hasText => chapter != null && chapter!.verses.isNotEmpty;
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
        versionId: j['versionId'] as String? ?? 'almeida1819',
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
        versionId: j['versionId'] as String? ?? 'almeida1819',
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
          for (final d in (j['completedDays'] as List? ?? const [])) d as int,
        },
        startedAt: j['startedAt'] != null
            ? DateTime.parse(j['startedAt'] as String)
            : null,
      );
}

class BiblePrefs {
  const BiblePrefs({
    this.versionId = 'almeida1819',
    this.fontSize = 18,
    this.lastBookId = 'joao',
    this.lastChapter = 1,
    this.ttsSpeechRate = 0.42,
    this.ttsVoiceName,
  });

  final String versionId;
  final double fontSize;
  final String lastBookId;
  final int lastChapter;

  /// Velocidade TTS do SO (tipicamente 0.2–0.75; ~0.42 soa mais natural em pt-BR).
  final double ttsSpeechRate;

  /// Nome da voz escolhida (`getVoices`); null = melhor pt-BR automática.
  final String? ttsVoiceName;

  BiblePrefs copyWith({
    String? versionId,
    double? fontSize,
    String? lastBookId,
    int? lastChapter,
    double? ttsSpeechRate,
    String? ttsVoiceName,
    bool clearTtsVoice = false,
  }) =>
      BiblePrefs(
        versionId: versionId ?? this.versionId,
        fontSize: fontSize ?? this.fontSize,
        lastBookId: lastBookId ?? this.lastBookId,
        lastChapter: lastChapter ?? this.lastChapter,
        ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
        ttsVoiceName:
            clearTtsVoice ? null : (ttsVoiceName ?? this.ttsVoiceName),
      );

  Map<String, dynamic> toJson() => {
        'versionId': versionId,
        'fontSize': fontSize,
        'lastBookId': lastBookId,
        'lastChapter': lastChapter,
        'ttsSpeechRate': ttsSpeechRate,
        if (ttsVoiceName != null) 'ttsVoiceName': ttsVoiceName,
      };

  factory BiblePrefs.fromJson(Map<String, dynamic> j) {
    var versionId = j['versionId'] as String? ?? 'almeida1819';
    // Prefs antigas apontavam para ara2 sem texto embutido.
    if (versionId == 'ara2' && j['migratedToDp'] != true) {
      // Mantém ara2; texto virá da API. Não força migração silenciosa.
    }
    return BiblePrefs(
      versionId: versionId,
      fontSize: (j['fontSize'] as num?)?.toDouble() ?? 18,
      lastBookId: j['lastBookId'] as String? ?? 'joao',
      lastChapter: j['lastChapter'] as int? ?? 1,
      ttsSpeechRate: ((j['ttsSpeechRate'] as num?)?.toDouble() ?? 0.42)
          .clamp(0.2, 0.75),
      ttsVoiceName: j['ttsVoiceName'] as String?,
    );
  }
}
