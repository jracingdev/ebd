import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:livro_registro/data/bible/bible_models.dart';

/// Texto completo Almeida 1819 (domínio público) embutido em assets.
class BibleAssetSource {
  BibleAssetSource();

  static const assetPath = 'assets/bible/almeida_1819.json';
  static const sourceNote =
      'Almeida 1819 (domínio público / Bíblia Livre). Fonte: midvash/bible-data.';

  Map<String, dynamic>? _books;
  String? _loadError;
  bool _loading = false;

  bool get isReady => _books != null;
  String? get loadError => _loadError;

  Future<void> ensureLoaded() async {
    if (_books != null || _loading) {
      while (_loading) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
      return;
    }
    _loading = true;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _books = Map<String, dynamic>.from(map['books'] as Map);
      _loadError = null;
    } catch (e) {
      _loadError = 'Falha ao carregar Almeida 1819: $e';
      _books = null;
    } finally {
      _loading = false;
    }
  }

  BibleChapter? chapter(String bookId, int chapter) {
    final books = _books;
    if (books == null) return null;
    final book = books[bookId];
    if (book is! Map) return null;
    final chapters = book['chapters'];
    if (chapters is! List || chapter < 1 || chapter > chapters.length) {
      return null;
    }
    final versesRaw = chapters[chapter - 1];
    if (versesRaw is! List || versesRaw.isEmpty) return null;
    final verses = <BibleVerse>[
      for (var i = 0; i < versesRaw.length; i++)
        BibleVerse(
          bookId: bookId,
          chapter: chapter,
          number: i + 1,
          text: versesRaw[i].toString(),
        ),
    ];
    return BibleChapter(
      bookId: bookId,
      chapter: chapter,
      verses: verses,
      sourceNote: sourceNote,
    );
  }

  List<BibleVerse> search(String query, {int limit = 80}) {
    final books = _books;
    if (books == null) return const [];
    final q = query.trim().toLowerCase();
    if (q.length < 2) return const [];
    final out = <BibleVerse>[];
    for (final entry in books.entries) {
      final bookId = entry.key;
      final book = entry.value;
      if (book is! Map) continue;
      final name = (book['name'] as String? ?? bookId).toLowerCase();
      final chapters = book['chapters'];
      if (chapters is! List) continue;
      for (var ci = 0; ci < chapters.length; ci++) {
        final verses = chapters[ci];
        if (verses is! List) continue;
        for (var vi = 0; vi < verses.length; vi++) {
          final text = verses[vi].toString();
          final ref = '$bookId ${ci + 1}:${vi + 1}';
          if (text.toLowerCase().contains(q) ||
              ref.contains(q) ||
              name.contains(q)) {
            out.add(
              BibleVerse(
                bookId: bookId,
                chapter: ci + 1,
                number: vi + 1,
                text: text,
              ),
            );
            if (out.length >= limit) return out;
          }
        }
      }
    }
    return out;
  }
}
