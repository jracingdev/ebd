import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:livro_registro/data/bible/bible_models.dart';

const _boxName = 'ebd_bible_v1';
const _keyPrefs = 'prefs';
const _keyBookmarks = 'bookmarks';
const _keyHighlights = 'highlights';
const _keyPlans = 'plan_progress';
const _keyChapterCache = 'chapter_cache';

class BibleStore {
  BibleStore(this._box);

  final Box _box;

  static Future<BibleStore> open() async {
    final box = await Hive.openBox(_boxName);
    return BibleStore(box);
  }

  BiblePrefs loadPrefs() {
    final raw = _box.get(_keyPrefs);
    if (raw == null) return const BiblePrefs();
    final map = raw is String ? jsonDecode(raw) : raw;
    return BiblePrefs.fromJson(Map<String, dynamic>.from(map as Map));
  }

  Future<void> savePrefs(BiblePrefs prefs) async {
    await _box.put(_keyPrefs, jsonEncode(prefs.toJson()));
  }

  List<BibleBookmark> loadBookmarks() {
    final raw = _box.get(_keyBookmarks);
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return [];
    return list
        .map((e) => BibleBookmark.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> saveBookmarks(List<BibleBookmark> items) async {
    await _box.put(
      _keyBookmarks,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  List<BibleHighlight> loadHighlights() {
    final raw = _box.get(_keyHighlights);
    if (raw == null) return [];
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return [];
    return list
        .map(
          (e) => BibleHighlight.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> saveHighlights(List<BibleHighlight> items) async {
    await _box.put(
      _keyHighlights,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Map<String, ReadingPlanProgress> loadPlanProgress() {
    final raw = _box.get(_keyPlans);
    if (raw == null) return {};
    final map = raw is String ? jsonDecode(raw) : raw;
    if (map is! Map) return {};
    return {
      for (final e in map.entries)
        e.key as String: ReadingPlanProgress.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        ),
    };
  }

  Future<void> savePlanProgress(Map<String, ReadingPlanProgress> map) async {
    await _box.put(
      _keyPlans,
      jsonEncode({for (final e in map.entries) e.key: e.value.toJson()}),
    );
  }

  /// Cache opcional de capítulos obtidos por API (JSON).
  Map<String, dynamic>? loadCachedChapter(String cacheKey) {
    final raw = _box.get(_keyChapterCache);
    if (raw == null) return null;
    final map = raw is String ? jsonDecode(raw) : raw;
    if (map is! Map) return null;
    final item = map[cacheKey];
    if (item == null) return null;
    return Map<String, dynamic>.from(item as Map);
  }

  Future<void> cacheChapter(String cacheKey, Map<String, dynamic> json) async {
    final raw = _box.get(_keyChapterCache);
    final map = <String, dynamic>{};
    if (raw != null) {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) {
        map.addAll(Map<String, dynamic>.from(decoded));
      }
    }
    map[cacheKey] = json;
    await _box.put(_keyChapterCache, jsonEncode(map));
  }
}
