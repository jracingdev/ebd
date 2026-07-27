import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:livro_registro/data/bible/bible_catalog.dart';
import 'package:livro_registro/data/bible/bible_models.dart';

/// Resultado de fetch remoto (capítulo ou erro acionável).
class BibleFetchResult {
  const BibleFetchResult.ok(this.chapter) : error = null;
  const BibleFetchResult.fail(this.error) : chapter = null;

  final BibleChapter? chapter;
  final String? error;
}

/// Fontes remotas: Midvash (público) e, se configurado, API.Bible (licenciado).
class BibleRemoteSource {
  BibleRemoteSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const midvashBase = 'https://api.midvash.com/v1';

  String? get apiBibleKey {
    final k = dotenv.env['BIBLE_API_KEY']?.trim();
    if (k == null || k.isEmpty || k.startsWith('YOUR_')) return null;
    return k;
  }

  bool get hasApiBibleKey => apiBibleKey != null;

  /// ID API.Bible por versão do app (opcional no .env).
  String? apiBibleIdFor(BibleVersion version) {
    final envKey = switch (version) {
      BibleVersion.ara2 => 'BIBLE_API_ID_ARA2',
      BibleVersion.ra => 'BIBLE_API_ID_RA',
      BibleVersion.sbb => 'BIBLE_API_ID_SBB',
      BibleVersion.ntlh => 'BIBLE_API_ID_NTLH',
      BibleVersion.almeida1819 => null,
    };
    if (envKey == null) return null;
    final v = dotenv.env[envKey]?.trim();
    if (v == null || v.isEmpty || v.startsWith('YOUR_')) return null;
    return v;
  }

  Future<BibleFetchResult> fetchChapter({
    required BibleVersion version,
    required String bookId,
    required int chapter,
  }) async {
    if (version.isLocalAsset) {
      return const BibleFetchResult.fail('Versão local não usa API remota.');
    }

    final apiId = apiBibleIdFor(version);
    if (hasApiBibleKey && apiId != null) {
      final r = await _fetchApiBible(
        bibleId: apiId,
        bookId: bookId,
        chapter: chapter,
        version: version,
      );
      if (r.chapter != null) return r;
      // Continua para Midvash se API.Bible falhar.
    }

    return _fetchMidvash(
      slug: version.remoteSlug!,
      bookId: bookId,
      chapter: chapter,
      version: version,
    );
  }

  Future<BibleFetchResult> _fetchMidvash({
    required String slug,
    required String bookId,
    required int chapter,
    required BibleVersion version,
  }) async {
    final bookSlug = kMidvashBookSlugs[bookId];
    if (bookSlug == null) {
      return BibleFetchResult.fail('Livro desconhecido: $bookId');
    }
    final uri = Uri.parse('$midvashBase/$slug/$bookSlug/$chapter');
    try {
      final res = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        return BibleFetchResult.fail(
          'API Midvash HTTP ${res.statusCode} para ${version.shortLabel}. '
          'Verifique a rede e tente de novo.',
        );
      }
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(map['data'] as Map? ?? map);
      final versesList = data['verses'];
      if (versesList is! List || versesList.isEmpty) {
        return BibleFetchResult.fail(
          'Capítulo sem versículos na API (${version.shortLabel}).',
        );
      }
      final verses = <BibleVerse>[
        for (var i = 0; i < versesList.length; i++)
          BibleVerse(
            bookId: bookId,
            chapter: chapter,
            number: i + 1,
            text: versesList[i].toString().trim(),
          ),
      ];
      return BibleFetchResult.ok(
        BibleChapter(
          bookId: bookId,
          chapter: chapter,
          verses: verses,
          sourceNote: version.remoteSourceNote,
        ),
      );
    } catch (e) {
      return BibleFetchResult.fail(
        'Sem rede ou falha ao buscar ${version.shortLabel}: $e',
      );
    }
  }

  Future<BibleFetchResult> _fetchApiBible({
    required String bibleId,
    required String bookId,
    required int chapter,
    required BibleVersion version,
  }) async {
    final key = apiBibleKey;
    if (key == null) {
      return const BibleFetchResult.fail(
        'Configure BIBLE_API_KEY no arquivo .env (API.Bible).',
      );
    }
    // API.Bible usa IDs OSIS curtos (GEN.1, JHN.1).
    final osis = _osisChapter(bookId, chapter);
    if (osis == null) {
      return BibleFetchResult.fail('Livro sem mapeamento OSIS: $bookId');
    }
    final uri = Uri.parse(
      'https://api.scripture.api.bible/v1/bibles/$bibleId/chapters/$osis',
    ).replace(queryParameters: {
      'content-type': 'text',
      'include-notes': 'false',
      'include-titles': 'false',
      'include-chapter-numbers': 'false',
      'include-verse-numbers': 'true',
    });
    try {
      final res = await _client.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'api-key': key,
        },
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 401 || res.statusCode == 403) {
        return const BibleFetchResult.fail(
          'Chave API.Bible inválida ou sem licença para esta versão. '
          'Ajuste BIBLE_API_KEY / IDs no .env.',
        );
      }
      if (res.statusCode != 200) {
        return BibleFetchResult.fail(
          'API.Bible HTTP ${res.statusCode}. Confira o ID da Bíblia no .env.',
        );
      }
      final map = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(map['data'] as Map? ?? {});
      final content = (data['content'] as String? ?? '').trim();
      if (content.isEmpty) {
        return const BibleFetchResult.fail('API.Bible retornou capítulo vazio.');
      }
      final verses = _parseApiBibleVerses(content, bookId, chapter);
      if (verses.isEmpty) {
        return const BibleFetchResult.fail(
          'Não foi possível interpretar os versículos da API.Bible.',
        );
      }
      return BibleFetchResult.ok(
        BibleChapter(
          bookId: bookId,
          chapter: chapter,
          verses: verses,
          sourceNote:
              'Texto via API.Bible (licenciado). ${version.label}. Cache local no aparelho.',
        ),
      );
    } catch (e) {
      return BibleFetchResult.fail('Falha API.Bible: $e');
    }
  }

  static List<BibleVerse> _parseApiBibleVerses(
    String content,
    String bookId,
    int chapter,
  ) {
    // Conteúdo tipicamente: "1 Texto… 2 Texto…" ou com ¶.
    final cleaned = content
        .replaceAll(RegExp(r'¶'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final matches = RegExp(r'(?:^|\s)(\d+)[^\d]').allMatches(cleaned).toList();
    if (matches.isEmpty) {
      return [
        BibleVerse(bookId: bookId, chapter: chapter, number: 1, text: cleaned),
      ];
    }
    final verses = <BibleVerse>[];
    for (var i = 0; i < matches.length; i++) {
      final numStr = matches[i].group(1)!;
      final start = matches[i].end;
      final end = i + 1 < matches.length ? matches[i + 1].start : cleaned.length;
      final text = cleaned.substring(start, end).trim();
      if (text.isEmpty) continue;
      verses.add(
        BibleVerse(
          bookId: bookId,
          chapter: chapter,
          number: int.tryParse(numStr) ?? (i + 1),
          text: text,
        ),
      );
    }
    return verses;
  }

  static String? _osisChapter(String bookId, int chapter) {
    const map = <String, String>{
      'gen': 'GEN', 'exo': 'EXO', 'lev': 'LEV', 'num': 'NUM', 'deu': 'DEU',
      'jos': 'JOS', 'jui': 'JDG', 'rut': 'RUT', '1sa': '1SA', '2sa': '2SA',
      '1rs': '1KI', '2rs': '2KI', '1cr': '1CH', '2cr': '2CH', 'esd': 'EZR',
      'nee': 'NEH', 'est': 'EST', 'jo': 'JOB', 'sal': 'PSA', 'pro': 'PRO',
      'ecl': 'ECC', 'can': 'SNG', 'isa': 'ISA', 'jer': 'JER', 'lam': 'LAM',
      'eze': 'EZK', 'dan': 'DAN', 'ose': 'HOS', 'joe': 'JOL', 'amo': 'AMO',
      'oba': 'OBA', 'jon': 'JON', 'miq': 'MIC', 'naa': 'NAM', 'hab': 'HAB',
      'sof': 'ZEP', 'age': 'HAG', 'zac': 'ZEC', 'mal': 'MAL', 'mat': 'MAT',
      'mar': 'MRK', 'luc': 'LUK', 'joao': 'JHN', 'ato': 'ACT', 'rom': 'ROM',
      '1co': '1CO', '2co': '2CO', 'gal': 'GAL', 'ef': 'EPH', 'fp': 'PHP',
      'cl': 'COL', '1ts': '1TH', '2ts': '2TH', '1tm': '1TI', '2tm': '2TI',
      'tt': 'TIT', 'fm': 'PHM', 'hb': 'HEB', 'tg': 'JAS', '1pe': '1PE',
      '2pe': '2PE', '1jo': '1JN', '2jo': '2JN', '3jo': '3JN', 'jd': 'JUD',
      'ap': 'REV',
    };
    final b = map[bookId];
    if (b == null) return null;
    return '$b.$chapter';
  }
}
