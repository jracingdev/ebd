import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livro_registro/config/app_config.dart';
import 'package:livro_registro/data/betel_catalog.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Extrai o máximo possível do site da Editora Betel (HTML público)
/// ou lê/atualiza via Edge Function `sync-betel` quando Supabase está ativo.
class BetelSyncService {
  static const base = 'https://www.editorabetel.com.br';

  /// Calcula trimestre corrente (1–4) e ano.
  static (int tri, int year) currentTrimester([DateTime? now]) {
    final d = now ?? DateTime.now();
    final tri = ((d.month - 1) ~/ 3) + 1;
    return (tri, d.year);
  }

  /// Retorna itens + fonte: `edge` | `client` | `static`.
  Future<(List<BetelCatalogItem>, String)> syncCurrentTrimester({
    bool preferEdgeFunction = true,
  }) async {
    final (tri, year) = currentTrimester();
    return syncTrimester(tri, year, preferEdgeFunction: preferEdgeFunction);
  }

  Future<(List<BetelCatalogItem>, String)> syncTrimester(
    int tri,
    int year, {
    bool preferEdgeFunction = true,
  }) async {
    if (preferEdgeFunction && AppConfig.supabaseConfigured) {
      try {
        final fromEdge = await _syncViaEdgeThenRead(tri, year);
        if (fromEdge.isNotEmpty) return (fromEdge, 'edge');
      } catch (e) {
        debugPrint('Betel edge sync falhou, fallback client: $e');
      }
    }
    final client = await _syncViaClientScrape(tri, year);
    if (client.isNotEmpty) return (client, 'client');
    return (_fromStaticCatalog(tri, year), 'static');
  }

  /// Invoca Edge `sync-betel` e lê `betel_catalog`.
  Future<List<BetelCatalogItem>> _syncViaEdgeThenRead(int tri, int year) async {
    final client = Supabase.instance.client;
    try {
      await client.functions.invoke('sync-betel');
    } catch (e) {
      debugPrint('invoke sync-betel: $e (ainda tenta ler catálogo)');
    }
    final triLabel = '$triº Trimestre $year';
    final rows = await client
        .from('betel_catalog')
        .select()
        .eq('trimestre', triLabel);
    final items = <BetelCatalogItem>[];
    for (final row in rows as List) {
      final m = Map<String, dynamic>.from(row as Map);
      items.add(
        BetelCatalogItem(
          grupo: m['grupo'] as String,
          trimestre: m['trimestre'] as String,
          serie: (m['serie'] as String?) ?? '',
          tema: m['tema'] as String?,
          sku: m['sku'] as String?,
          capaUrl: m['capa_url'] as String?,
          produtoUrl: m['produto_url'] as String?,
          preco: (m['preco'] as num?)?.toDouble(),
        ),
      );
    }
    // Adulto → também Varões localmente (como no scrape).
    final cibe = items.where((i) => i.grupo == 'CIBE').toList();
    if (cibe.isNotEmpty && !items.any((i) => i.grupo == 'Varões')) {
      final src = cibe.first;
      items.add(
        BetelCatalogItem(
          grupo: 'Varões',
          trimestre: src.trimestre,
          serie: src.serie,
          tema: src.tema,
          sku: src.sku,
          capaUrl: src.capaUrl,
          produtoUrl: src.produtoUrl,
          preco: src.preco,
        ),
      );
    }
    return items;
  }

  Future<List<BetelCatalogItem>> _syncViaClientScrape(int tri, int year) async {
    final url = Uri.parse('$base/escola-dominical-$tri-trimestre-$year');
    final res = await http.get(url, headers: {
      'User-Agent': 'EBDApp/1.0',
      'Accept': 'text/html',
    });
    if (res.statusCode != 200) {
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
