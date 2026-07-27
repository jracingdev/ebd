import 'package:flutter/foundation.dart';
import 'package:livro_registro/data/bible/bible_models.dart';
import 'package:livro_registro/data/bible/bible_store.dart';
import 'package:livro_registro/data/bible/sample_texts.dart';
import 'package:uuid/uuid.dart';

/// Repositório da Bíblia EBD: amostras locais + Hive + gancho para API futura.
class BibleRepository extends ChangeNotifier {
  BibleRepository(this._store);

  final BibleStore _store;
  final _uuid = const Uuid();

  late BiblePrefs prefs = _store.loadPrefs();
  List<BibleBookmark> bookmarks = [];
  List<BibleHighlight> highlights = [];
  Map<String, ReadingPlanProgress> planProgress = {};

  BibleVersion get version => BibleVersion.fromId(prefs.versionId);

  Future<void> load() async {
    prefs = _store.loadPrefs();
    bookmarks = _store.loadBookmarks();
    highlights = _store.loadHighlights();
    planProgress = _store.loadPlanProgress();
    notifyListeners();
  }

  Future<void> setVersion(BibleVersion v) async {
    prefs = prefs.copyWith(versionId: v.id);
    await _store.savePrefs(prefs);
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    prefs = prefs.copyWith(fontSize: size.clamp(14, 28));
    await _store.savePrefs(prefs);
    notifyListeners();
  }

  Future<void> rememberPlace(String bookId, int chapter) async {
    prefs = prefs.copyWith(lastBookId: bookId, lastChapter: chapter);
    await _store.savePrefs(prefs);
    notifyListeners();
  }

  List<BibleBook> get books => kBibleBooks;

  List<ReadingPlan> get plans => kEbdReadingPlans;

  /// Carrega capítulo: amostra local, depois cache Hive, depois null (offline).
  Future<BibleChapter?> loadChapter(String bookId, int chapter) async {
    final sample = sampleChapter(bookId, chapter);
    if (sample != null) return sample;

    final key = '${prefs.versionId}:$bookId:$chapter';
    final cached = _store.loadCachedChapter(key);
    if (cached != null) {
      final verses = (cached['verses'] as List? ?? const [])
          .map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return BibleVerse(
              bookId: bookId,
              chapter: chapter,
              number: m['number'] as int,
              text: m['text'] as String,
            );
          })
          .toList();
      return BibleChapter(
        bookId: bookId,
        chapter: chapter,
        verses: verses,
        sourceNote: cached['sourceNote'] as String?,
      );
    }

    // Gancho para API licenciada (falha graciosa offline).
    // Ver docs/BIBLIA.md — não há endpoint embutido por padrão.
    return null;
  }

  List<BibleVerse> search(String query) => searchSamples(query);

  Future<void> toggleBookmark({
    required String bookId,
    required int chapter,
    required int verse,
    String? note,
  }) async {
    final existing = bookmarks.where(
      (b) =>
          b.versionId == prefs.versionId &&
          b.bookId == bookId &&
          b.chapter == chapter &&
          b.verse == verse,
    );
    if (existing.isNotEmpty) {
      bookmarks = bookmarks.where((b) => b.id != existing.first.id).toList();
    } else {
      bookmarks = [
        BibleBookmark(
          id: _uuid.v4(),
          versionId: prefs.versionId,
          bookId: bookId,
          chapter: chapter,
          verse: verse,
          createdAt: DateTime.now(),
          note: note,
          colorHex: '#2F5D50',
        ),
        ...bookmarks,
      ];
    }
    await _store.saveBookmarks(bookmarks);
    notifyListeners();
  }

  bool isBookmarked(String bookId, int chapter, int verse) => bookmarks.any(
        (b) =>
            b.versionId == prefs.versionId &&
            b.bookId == bookId &&
            b.chapter == chapter &&
            b.verse == verse,
      );

  Future<void> removeBookmark(String id) async {
    bookmarks = bookmarks.where((b) => b.id != id).toList();
    await _store.saveBookmarks(bookmarks);
    notifyListeners();
  }

  Future<void> toggleHighlight({
    required String bookId,
    required int chapter,
    required int verse,
    String colorHex = '#B8892B',
  }) async {
    final existing = highlights.where(
      (h) =>
          h.versionId == prefs.versionId &&
          h.bookId == bookId &&
          h.chapter == chapter &&
          h.verse == verse,
    );
    if (existing.isNotEmpty) {
      highlights = highlights.where((h) => h.id != existing.first.id).toList();
    } else {
      highlights = [
        ...highlights,
        BibleHighlight(
          id: _uuid.v4(),
          versionId: prefs.versionId,
          bookId: bookId,
          chapter: chapter,
          verse: verse,
          colorHex: colorHex,
          createdAt: DateTime.now(),
        ),
      ];
    }
    await _store.saveHighlights(highlights);
    notifyListeners();
  }

  BibleHighlight? highlightFor(String bookId, int chapter, int verse) {
    for (final h in highlights) {
      if (h.versionId == prefs.versionId &&
          h.bookId == bookId &&
          h.chapter == chapter &&
          h.verse == verse) {
        return h;
      }
    }
    return null;
  }

  ReadingPlanProgress progressFor(String planId) =>
      planProgress[planId] ??
      ReadingPlanProgress(planId: planId, completedDays: {});

  Future<void> togglePlanDay(String planId, int day) async {
    final current = progressFor(planId);
    final next = Set<int>.from(current.completedDays);
    if (next.contains(day)) {
      next.remove(day);
    } else {
      next.add(day);
    }
    planProgress = {
      ...planProgress,
      planId: ReadingPlanProgress(
        planId: planId,
        completedDays: next,
        startedAt: current.startedAt ?? DateTime.now(),
      ),
    };
    await _store.savePlanProgress(planProgress);
    notifyListeners();
  }
}
