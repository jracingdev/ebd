import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:livro_registro/data/harpa/harpa_models.dart';

const _boxName = 'ebd_harpa_v1';
const _keyPrefs = 'prefs';
const _keyFavorites = 'favorites';
const _keyLyricsCache = 'lyrics_cache';

class HarpaStore {
  HarpaStore(this._box);

  final Box _box;

  static Future<HarpaStore> open() async {
    final box = await Hive.openBox(_boxName);
    return HarpaStore(box);
  }

  HarpaPrefs loadPrefs() {
    final raw = _box.get(_keyPrefs);
    if (raw == null) return const HarpaPrefs();
    final map = raw is String ? jsonDecode(raw) : raw;
    return HarpaPrefs.fromJson(Map<String, dynamic>.from(map as Map));
  }

  Future<void> savePrefs(HarpaPrefs prefs) async {
    await _box.put(_keyPrefs, jsonEncode(prefs.toJson()));
  }

  /// Números favoritos (ordem de adição, mais recente primeiro na UI).
  List<int> loadFavorites() {
    final raw = _box.get(_keyFavorites);
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return [];
    return [for (final e in list) (e as num).toInt()];
  }

  Future<void> saveFavorites(List<int> numbers) async {
    await _box.put(_keyFavorites, jsonEncode(numbers));
  }

  Map<String, dynamic> _lyricsCacheMap() {
    final raw = _box.get(_keyLyricsCache);
    if (raw == null) return {};
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return {};
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic>? loadCachedLyrics(int number) {
    final item = _lyricsCacheMap()['$number'];
    if (item == null) return null;
    return Map<String, dynamic>.from(item as Map);
  }

  Future<void> cacheLyrics(int number, Map<String, dynamic> json) async {
    final map = _lyricsCacheMap();
    map['$number'] = json;
    await _box.put(_keyLyricsCache, jsonEncode(map));
  }
}
