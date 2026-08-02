import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:livro_registro/data/harpa/harpa_models.dart';

/// Fonte remota de letras (terceiro; disponibilidade não garantida).
///
/// Ver `docs/HARPA.md` — letras são obra CPAD; cache só no aparelho do usuário.
class HarpaRemoteSource {
  HarpaRemoteSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const baseUrl = 'https://harpa-api.onrender.com';

  Future<HarpaHymn?> fetchHymn(int number) async {
    final uri = Uri.parse('$baseUrl/hymns/$number');
    final res = await _client.get(uri).timeout(const Duration(seconds: 25));
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    if (decoded is! Map) return null;
    final hymnMap = decoded['hymn'] is Map
        ? Map<String, dynamic>.from(decoded['hymn'] as Map)
        : Map<String, dynamic>.from(decoded);
    hymnMap['number'] = hymnMap['number'] ?? number;
    final hymn = HarpaHymn.fromJson(hymnMap);
    if (!hymn.hasLyrics) return null;
    return HarpaHymn(
      number: number,
      title: hymn.title,
      stanzas: hymn.stanzas,
      sourceNote:
          'Cache local via API pública ($baseUrl). Letras © CPAD — ver docs/HARPA.md.',
    );
  }
}
