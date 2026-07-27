import 'package:flutter/foundation.dart';
import 'package:livro_registro/data/bible/bible_asset_source.dart';
import 'package:livro_registro/data/bible/bible_catalog.dart';
import 'package:livro_registro/data/bible/bible_models.dart';
import 'package:livro_registro/data/bible/bible_store.dart';
import 'package:livro_registro/services/bible_remote_source.dart';
import 'package:uuid/uuid.dart';

/// Repositório da Bíblia EBD: asset DP + APIs remotas + cache Hive.
class BibleRepository extends ChangeNotifier {
  BibleRepository(
    this._store, {
    BibleAssetSource? asset,
    BibleRemoteSource? remote,
  })  : _asset = asset ?? BibleAssetSource(),
        _remote = remote ?? BibleRemoteSource();

  final BibleStore _store;
  final BibleAssetSource _asset;
  final BibleRemoteSource _remote;
  final _uuid = const Uuid();

  late BiblePrefs prefs = _store.loadPrefs();
  List<BibleBookmark> bookmarks = [];
  List<BibleHighlight> highlights = [];
  Map<String, ReadingPlanProgress> planProgress = {};

  /// Progresso de download offline (0..1) por versionId; null = idle.
  final Map<String, double> downloadProgress = {};
  final Map<String, String> lastChapterErrors = {};

  BibleVersion get version => BibleVersion.fromId(prefs.versionId);

  bool get hasApiBibleKey => _remote.hasApiBibleKey;

  Future<void> load() async {
    prefs = _store.loadPrefs();
    bookmarks = _store.loadBookmarks();
    highlights = _store.loadHighlights();
    planProgress = _store.loadPlanProgress();
    await _asset.ensureLoaded();
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

  Future<void> setTtsSpeechRate(double rate) async {
    prefs = prefs.copyWith(ttsSpeechRate: rate.clamp(0.2, 0.75));
    await _store.savePrefs(prefs);
    notifyListeners();
  }

  Future<void> setTtsVoiceName(String? voiceName) async {
    if (voiceName == null || voiceName.isEmpty) {
      prefs = prefs.copyWith(clearTtsVoice: true);
    } else {
      prefs = prefs.copyWith(ttsVoiceName: voiceName);
    }
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

  int cachedChapterCount(String versionId) =>
      _store.countCachedChapters(versionId);

  int get totalCanonChapters =>
      kBibleBooks.fold(0, (sum, b) => sum + b.chapters);

  bool isVersionFullyCached(String versionId) =>
      cachedChapterCount(versionId) >= totalCanonChapters;

  /// Carrega capítulo: asset local, cache Hive, depois API remota.
  Future<BibleChapterLoad> loadChapter(String bookId, int chapter) async {
    final v = version;

    if (v.isLocalAsset) {
      await _asset.ensureLoaded();
      final local = _asset.chapter(bookId, chapter);
      if (local != null) {
        lastChapterErrors.remove('${v.id}:$bookId:$chapter');
        return BibleChapterLoad.ok(local);
      }
      return BibleChapterLoad.fail(
        errorMessage: _asset.loadError ??
            'Capítulo não encontrado no asset Almeida 1819 ($bookId $chapter).',
        canRetry: true,
      );
    }

    final key = '${v.id}:$bookId:$chapter';
    final cached = _store.loadCachedChapter(key);
    if (cached != null) {
      final parsed = _chapterFromCache(cached, bookId, chapter);
      if (parsed != null) {
        lastChapterErrors.remove(key);
        return BibleChapterLoad.ok(parsed);
      }
    }

    final fetched = await _remote.fetchChapter(
      version: v,
      bookId: bookId,
      chapter: chapter,
    );
    if (fetched.chapter != null) {
      await _store.cacheChapter(key, {
        'verses': [
          for (final verse in fetched.chapter!.verses)
            {'number': verse.number, 'text': verse.text},
        ],
        'sourceNote': fetched.chapter!.sourceNote,
      });
      lastChapterErrors.remove(key);
      notifyListeners();
      return BibleChapterLoad.ok(fetched.chapter!);
    }

    final msg = fetched.error ??
        'Capítulo indisponível em ${v.shortLabel}. '
            'Conecte-se à internet ou baixe a versão para offline. '
            'Como alternativa imediata, use Almeida 1819 (domínio público).';
    lastChapterErrors[key] = msg;
    notifyListeners();
    return BibleChapterLoad.fail(errorMessage: msg);
  }

  BibleChapter? _chapterFromCache(
    Map<String, dynamic> cached,
    String bookId,
    int chapter,
  ) {
    final verses = (cached['verses'] as List? ?? const [])
        .map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return BibleVerse(
            bookId: bookId,
            chapter: chapter,
            number: (m['number'] as num).toInt(),
            text: m['text'] as String,
          );
        })
        .toList();
    if (verses.isEmpty) return null;
    return BibleChapter(
      bookId: bookId,
      chapter: chapter,
      verses: verses,
      sourceNote: cached['sourceNote'] as String?,
    );
  }

  /// Baixa todos os capítulos da versão remota atual para cache offline + busca.
  Future<void> downloadCurrentVersionOffline({
    void Function(double progress, String label)? onProgress,
  }) async {
    final v = version;
    if (v.isLocalAsset) return;
    if (downloadProgress.containsKey(v.id)) return;

    downloadProgress[v.id] = 0;
    notifyListeners();
    final total = totalCanonChapters;
    var done = 0;
    try {
      for (final book in kBibleBooks) {
        for (var ch = 1; ch <= book.chapters; ch++) {
          final key = '${v.id}:${book.id}:$ch';
          if (_store.loadCachedChapter(key) == null) {
            final fetched = await _remote.fetchChapter(
              version: v,
              bookId: book.id,
              chapter: ch,
            );
            if (fetched.chapter != null) {
              await _store.cacheChapter(key, {
                'verses': [
                  for (final verse in fetched.chapter!.verses)
                    {'number': verse.number, 'text': verse.text},
                ],
                'sourceNote': fetched.chapter!.sourceNote,
              });
            }
            // Evita martelar a API.
            await Future<void>.delayed(const Duration(milliseconds: 35));
          }
          done++;
          final p = done / total;
          downloadProgress[v.id] = p;
          onProgress?.call(p, '${book.name} $ch');
          if (done % 20 == 0) notifyListeners();
        }
      }
    } finally {
      downloadProgress.remove(v.id);
      notifyListeners();
    }
  }

  List<BibleVerse> search(String query) {
    final q = query.trim();
    if (q.length < 2) return const [];

    if (version.isLocalAsset) {
      return _asset.search(q);
    }

    // Busca no cache local da versão (completo após download offline).
    final out = <BibleVerse>[];
    final qLower = q.toLowerCase();
    for (final book in kBibleBooks) {
      for (var ch = 1; ch <= book.chapters; ch++) {
        final key = '${version.id}:${book.id}:$ch';
        final cached = _store.loadCachedChapter(key);
        if (cached == null) continue;
        final chapter = _chapterFromCache(cached, book.id, ch);
        if (chapter == null) continue;
        for (final v in chapter.verses) {
          if (v.text.toLowerCase().contains(qLower) ||
              '${book.name} ${v.chapter}:${v.number}'.toLowerCase().contains(qLower)) {
            out.add(v);
            if (out.length >= 80) return out;
          }
        }
      }
    }
    return out;
  }

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
