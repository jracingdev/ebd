import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:livro_registro/data/bible/bible_models.dart';

const _boxName = 'ebd_bible_v1';
const _keyPrefs = 'prefs';
const _keyBookmarks = 'bookmarks';
const _keyHighlights = 'highlights';
const _keyPlans = 'plan_progress';
const _keyChapterCache = 'chapter_cache';
const _keyChaptersRead = 'chapters_read';
const _keyReadDates = 'read_dates';

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

  Map<String, dynamic> _chapterCacheMap() {
    final raw = _box.get(_keyChapterCache);
    if (raw == null) return {};
    final decoded = raw is String ? jsonDecode(raw) : raw;
    if (decoded is! Map) return {};
    return Map<String, dynamic>.from(decoded);
  }

  /// Cache de capítulos obtidos por API (JSON).
  Map<String, dynamic>? loadCachedChapter(String cacheKey) {
    final item = _chapterCacheMap()[cacheKey];
    if (item == null) return null;
    return Map<String, dynamic>.from(item as Map);
  }

  int countCachedChapters(String versionId) {
    final prefix = '$versionId:';
    var n = 0;
    for (final key in _chapterCacheMap().keys) {
      if (key.toString().startsWith(prefix)) n++;
    }
    return n;
  }

  Future<void> cacheChapter(String cacheKey, Map<String, dynamic> json) async {
    final map = _chapterCacheMap();
    map[cacheKey] = json;
    await _box.put(_keyChapterCache, jsonEncode(map));
  }

  /// Chaves `bookId:chapter` já marcadas como lidas.
  Set<String> loadChaptersRead() {
    final raw = _box.get(_keyChaptersRead);
    if (raw == null) return {};
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return {};
    return {for (final e in list) e.toString()};
  }

  Future<void> saveChaptersRead(Set<String> keys) async {
    await _box.put(_keyChaptersRead, jsonEncode(keys.toList()..sort()));
  }

  /// Datas `yyyy-MM-dd` em que houve leitura (para streak).
  Set<String> loadReadDates() {
    final raw = _box.get(_keyReadDates);
    if (raw == null) return {};
    final list = raw is String ? jsonDecode(raw) : raw;
    if (list is! List) return {};
    return {for (final e in list) e.toString()};
  }

  Future<void> saveReadDates(Set<String> dates) async {
    await _box.put(_keyReadDates, jsonEncode(dates.toList()..sort()));
  }
}
