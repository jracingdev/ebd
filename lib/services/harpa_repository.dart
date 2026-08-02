import 'package:flutter/foundation.dart';
import 'package:livro_registro/data/harpa/harpa_catalog.dart';
import 'package:livro_registro/data/harpa/harpa_models.dart';
import 'package:livro_registro/data/harpa/harpa_store.dart';
import 'package:livro_registro/services/harpa_remote_source.dart';

/// Repositório da Harpa EBD: catálogo local + letras API/cache/asset opcional.
class HarpaRepository extends ChangeNotifier {
  HarpaRepository(
    this._store, {
    HarpaRemoteSource? remote,
  }) : _remote = remote ?? HarpaRemoteSource();

  final HarpaStore _store;
  final HarpaRemoteSource _remote;

  late HarpaPrefs prefs = _store.loadPrefs();
  List<int> favorites = [];

  static const cpadInfoUrl = 'https://www.cpad.com.br';

  Future<void> load() async {
    prefs = _store.loadPrefs();
    favorites = _store.loadFavorites();
    await HarpaCatalog.ensureLoaded();
    notifyListeners();
  }

  List<HarpaCatalogEntry> get catalog => HarpaCatalog.entries;

  HarpaCatalogEntry? entryByNumber(int n) => HarpaCatalog.byNumber(n);

  List<HarpaCatalogEntry> search(String query) => HarpaCatalog.search(query);

  bool isFavorite(int number) => favorites.contains(number);

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

  Future<void> rememberHymn(int number) async {
    final n = number.clamp(1, HarpaCatalog.maxNumber);
    prefs = prefs.copyWith(lastHymnNumber: n);
    await _store.savePrefs(prefs);
    notifyListeners();
  }

  Future<void> toggleFavorite(int number) async {
    if (favorites.contains(number)) {
      favorites = [for (final n in favorites) if (n != number) n];
    } else {
      favorites = [number, ...favorites];
    }
    await _store.saveFavorites(favorites);
    notifyListeners();
  }

  Future<HarpaLoadResult> loadHymn(int number) async {
    final entry = HarpaCatalog.byNumber(number);
    final title = entry?.title ?? 'Hino $number';

    final optional = await HarpaCatalog.loadOptionalLyrics(number);
    if (optional != null && optional.hasLyrics) {
      await rememberHymn(number);
      return HarpaLoadResult(hymn: optional);
    }

    final cached = _store.loadCachedLyrics(number);
    if (cached != null) {
      final hymn = HarpaHymn.fromJson(cached);
      if (hymn.hasLyrics) {
        await rememberHymn(number);
        return HarpaLoadResult(hymn: hymn);
      }
    }

    try {
      final remote = await _remote.fetchHymn(number);
      if (remote != null && remote.hasLyrics) {
        final withTitle = HarpaHymn(
          number: number,
          title: remote.title.isNotEmpty ? remote.title : title,
          stanzas: remote.stanzas,
          sourceNote: remote.sourceNote,
        );
        await _store.cacheLyrics(number, withTitle.toJson());
        await rememberHymn(number);
        return HarpaLoadResult(hymn: withTitle);
      }
    } catch (e, st) {
      debugPrint('HarpaRemoteSource: $e\n$st');
    }

    await rememberHymn(number);
    return HarpaLoadResult(
      hymn: HarpaHymn(number: number, title: title, stanzas: const []),
      missingLyrics: true,
      errorMessage:
          'Letra indisponível offline. O catálogo mostra o título; '
          'as letras da Harpa Cristã são © CPAD. Com internet, o app tenta '
          'buscar e guardar no cache do aparelho. Para uso oficial, consulte a CPAD.',
    );
  }
}
