import 'package:http/http.dart' as http;
import 'package:livro_registro/data/betel_catalog.dart';
import 'package:livro_registro/data/user_models.dart';

/// Extrai o máximo possível do site da Editora Betel (HTML público).
class BetelSyncService {
  static const base = 'https://www.editorabetel.com.br';

  /// Calcula trimestre corrente (1–4) e ano.
  static (int tri, int year) currentTrimester([DateTime? now]) {
    final d = now ?? DateTime.now();
    final tri = ((d.month - 1) ~/ 3) + 1;
    return (tri, d.year);
  }

  Future<List<BetelCatalogItem>> syncCurrentTrimester() async {
    final (tri, year) = currentTrimester();
    return syncTrimester(tri, year);
  }

  Future<List<BetelCatalogItem>> syncTrimester(int tri, int year) async {
    final url = Uri.parse('$base/escola-dominical-$tri-trimestre-$year');
    final res = await http.get(url, headers: {
      'User-Agent': 'EBDApp/1.0',
      'Accept': 'text/html',
    });
    if (res.statusCode != 200) {
      // Fallback para catálogo embutido se o site falhar.
      return _fromStaticCatalog(tri, year);
    }
    final html = res.body;
    final items = <BetelCatalogItem>[];
    final linkRe = RegExp(
      r'href="(https://www\.editorabetel\.com\.br/escola-dominical/revista-[^"]+)"[^>]*>[\s\S]*?REVISTA\s+([^<]+)',
      caseSensitive: false,
    );
    for (final m in linkRe.allMatches(html)) {
      final produtoUrl = m.group(1)!;
      final titulo = m.group(2)!.replaceAll(RegExp(r'\s+'), ' ').trim();
      final skuMatch = RegExp(r'-(\d{6})$').firstMatch(produtoUrl);
      final grupo = _mapTituloToGrupo(titulo);
      if (grupo == null) continue;
      if (titulo.toUpperCase().contains('PROFESSOR')) continue;
      items.add(BetelCatalogItem(
        grupo: grupo,
        trimestre: '$triº Trimestre $year',
        serie: _serieFromTitulo(titulo),
        sku: skuMatch?.group(1),
        produtoUrl: produtoUrl,
        capaUrl: betelCatalog[grupo]?['capa'],
        tema: betelCatalog[grupo]?['revista'],
      ));
    }

    // Enriquecer capas/temas via páginas de produto (limitado).
    final enriched = <BetelCatalogItem>[];
    for (final item in items) {
      enriched.add(await _enrichProduct(item));
    }
    if (enriched.isEmpty) return _fromStaticCatalog(tri, year);
    return enriched;
  }

  Future<BetelCatalogItem> _enrichProduct(BetelCatalogItem item) async {
    if (item.produtoUrl == null) return item;
    try {
      final res = await http.get(Uri.parse(item.produtoUrl!), headers: {
        'User-Agent': 'EBDApp/1.0',
      });
      if (res.statusCode != 200) return item;
      final html = res.body;
      final capa = RegExp(
        r'(https://www\.editorabetel\.com\.br/uploads/imagens/[a-zA-Z0-9]+_m\.jpg)',
      ).firstMatch(html)?.group(1);
      final temaMatch = RegExp(
        r'[Tt]ema[:\s]+([^<\n]{8,120})',
      ).firstMatch(html);
      final precoMatch = RegExp(r'R\$\s*([\d.,]+)').firstMatch(html);
      return BetelCatalogItem(
        grupo: item.grupo,
        trimestre: item.trimestre,
        serie: item.serie,
        sku: item.sku,
        produtoUrl: item.produtoUrl,
        capaUrl: capa ?? item.capaUrl,
        tema: temaMatch?.group(1)?.trim() ?? item.tema,
        preco: precoMatch == null
            ? item.preco
            : double.tryParse(
                precoMatch.group(1)!.replaceAll('.', '').replaceAll(',', '.'),
              ),
      );
    } catch (_) {
      return item;
    }
  }

  List<BetelCatalogItem> _fromStaticCatalog(int tri, int year) {
    final triLabel = '$triº Trimestre $year';
    return betelCatalog.entries.map((e) {
      return BetelCatalogItem(
        grupo: e.key,
        trimestre: e.value['trimestre'] ?? triLabel,
        serie: e.value['revista'] ?? e.key,
        capaUrl: e.value['capa'],
        tema: e.value['revista'],
      );
    }).toList();
  }

  String? _mapTituloToGrupo(String titulo) {
    final t = titulo.toUpperCase();
    if (t.contains('CRESCER') || t.contains('MATERNAL')) {
      return 'Maternal (2-3 anos)';
    }
    if (t.contains('CONHECER') || t.contains('PRE ESCOLAR') || t.contains('PRÉ')) {
      return 'Pré-escolar (4-5 anos)';
    }
    if (t.contains('APRENDER') || t.contains('PRIMAR')) {
      return 'Primários (6-8 anos)';
    }
    if (t.contains('SABER') || t.contains('JUNIOR')) {
      return 'Juniores (9-11 anos)';
    }
    if (t.contains('ADOLESCER') || t.contains('12 A 14')) {
      return 'Adolescentes 12-14';
    }
    if (t.contains('VIVER+') || t.contains('15 A 17')) {
      return 'Adolescentes 15-17';
    }
    if (t.contains('CONECTAR') || t.contains('JOVENS')) {
      return 'Jovens';
    }
    if (t.contains('ADULTO') || t.contains('DOMINICAL')) {
      // Adulto alimenta CIBE e Varões
      return 'CIBE';
    }
    return null;
  }

  String _serieFromTitulo(String titulo) {
    final t = titulo.toUpperCase();
    if (t.contains('CRESCER')) return 'CRESCER+';
    if (t.contains('CONHECER')) return 'CONHECER+';
    if (t.contains('APRENDER')) return 'APRENDER+';
    if (t.contains('SABER')) return 'SABER+';
    if (t.contains('ADOLESCER')) return 'ADOLESCER+';
    if (t.contains('VIVER')) return 'VIVER+';
    if (t.contains('CONECTAR')) return 'CONECTAR+';
    if (t.contains('ADULTO')) return 'Betel Dominical Adulto';
    return titulo;
  }

  /// Gera 13 domingos a partir de uma data inicial (primeiro domingo do tri).
  static List<DateTime> thirteenSundays(DateTime startSunday) {
    return List.generate(13, (i) => startSunday.add(Duration(days: 7 * i)));
  }
}
