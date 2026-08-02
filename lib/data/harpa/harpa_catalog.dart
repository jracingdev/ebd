import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:livro_registro/data/harpa/harpa_models.dart';

/// Catálogo embutido: número + título (1–640).
class HarpaCatalog {
  HarpaCatalog._();

  static const assetPath = 'assets/harpa/catalog.json';
  static const optionalLyricsPath = 'assets/harpa/hinos.json';
  static const maxNumber = 640;

  static List<HarpaCatalogEntry>? _entries;
  static Map<int, HarpaHymn>? _optionalLyrics;

  static List<HarpaCatalogEntry> get entries =>
      List.unmodifiable(_entries ?? const []);

  static Future<void> ensureLoaded() async {
    if (_entries != null) return;
    final raw = await rootBundle.loadString(assetPath);
    final list = jsonDecode(raw) as List<dynamic>;
    _entries = [
      for (final e in list)
        HarpaCatalogEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ]..sort((a, b) => a.number.compareTo(b.number));
  }

  static HarpaCatalogEntry? byNumber(int number) {
    final all = _entries;
    if (all == null) return null;
    for (final e in all) {
      if (e.number == number) return e;
    }
    return null;
  }

  static List<HarpaCatalogEntry> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return entries;
    final asNum = int.tryParse(q);
    return [
      for (final e in entries)
        if ((asNum != null && e.number == asNum) ||
            e.title.toLowerCase().contains(q) ||
            e.number.toString().contains(q))
          e,
    ];
  }

  /// Asset opcional com letras licenciadas (não versionar scrape).
  static Future<HarpaHymn?> loadOptionalLyrics(int number) async {
    await _ensureOptionalLyrics();
    return _optionalLyrics?[number];
  }

  static Future<void> _ensureOptionalLyrics() async {
    if (_optionalLyrics != null) return;
    _optionalLyrics = {};
    try {
      final raw = await rootBundle.loadString(optionalLyricsPath);
      final decoded = jsonDecode(raw);
      final list = decoded is List
          ? decoded
          : (decoded is Map && decoded['hinos'] is List)
              ? decoded['hinos'] as List
              : const [];
      for (final e in list) {
        final hymn = HarpaHymn.fromJson(Map<String, dynamic>.from(e as Map));
        if (hymn.number > 0) _optionalLyrics![hymn.number] = hymn;
      }
    } catch (_) {
      // Asset ausente: esperado em builds sem licença CPAD.
    }
  }
}
