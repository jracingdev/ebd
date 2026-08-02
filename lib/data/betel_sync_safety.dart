import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/user_models.dart';

/// Resultado do sync Betel (catálogo + opcionalmente edições novas).
class BetelSyncResult {
  const BetelSyncResult({
    required this.catalogItems,
    required this.source,
    required this.editionsCreated,
    required this.editionsUpdated,
    required this.catalogTrimestre,
    required this.operationalDataUnchanged,
    this.pendingNewEditionKeys = const [],
  });

  final int catalogItems;
  final String source;
  final int editionsCreated;
  final int editionsUpdated;
  final String? catalogTrimestre;

  /// Alunos / entregas / ofertas / presença não foram alterados.
  final bool operationalDataUnchanged;

  /// Chaves `grupo|trimestre` que ainda faltam como edição local.
  final List<String> pendingNewEditionKeys;
}

/// Snapshot mínimo para garantir que o sync Betel não zere dados operacionais.
class OperationalDataSnapshot {
  const OperationalDataSnapshot({
    required this.students,
    required this.records,
    required this.finances,
    required this.attendance,
    required this.lessons,
    required this.editionIds,
  });

  final int students;
  final int records;
  final int finances;
  final int attendance;
  final int lessons;
  final Set<String> editionIds;

  /// Contagens operacionais iguais e nenhuma edição antiga removida.
  bool preservedBy(OperationalDataSnapshot after) =>
      students == after.students &&
      records == after.records &&
      finances == after.finances &&
      attendance == after.attendance &&
      lessons == after.lessons &&
      editionIds.every(after.editionIds.contains);
}

/// Resolve a edição “ativa” da turma sem trocar silenciosamente o trimestre.
///
/// Prioridade: pin válido → edição com entregas → mais recente por criadoEm.
Edition? resolveCurrentEdition({
  required List<Edition> editions,
  required String grupo,
  String? pinnedEditionId,
  List<DeliveryRecord> records = const [],
}) {
  final eds = editions.where((e) => e.grupo == grupo).toList();
  if (eds.isEmpty) return null;

  if (pinnedEditionId != null) {
    for (final e in eds) {
      if (e.id == pinnedEditionId) return e;
    }
  }

  final withRecords = eds.where((e) => records.any((r) => r.edicaoId == e.id));
  if (withRecords.isNotEmpty) {
    final list = withRecords.toList()
      ..sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
    return list.first;
  }

  eds.sort((a, b) => b.criadoEm.compareTo(a.criadoEm));
  return eds.first;
}

/// Edições do catálogo que ainda não existem localmente (grupo + trimestre).
List<BetelCatalogItem> missingEditionsFromCatalog({
  required List<BetelCatalogItem> catalog,
  required List<Edition> editions,
}) {
  final missing = <BetelCatalogItem>[];
  final seen = <String>{};
  for (final item in catalog) {
    final key = '${item.grupo}|${item.trimestre}';
    if (seen.contains(key)) continue;
    seen.add(key);
    final exists = editions.any(
      (e) => e.grupo == item.grupo && e.trimestre == item.trimestre,
    );
    if (!exists) missing.add(item);
  }
  return missing;
}

/// True se o trimestre do catálogo difere de alguma edição já ativa pinada/atual.
bool catalogTrimestreDiffersFromActive({
  required String? catalogTrimestre,
  required List<Edition> activeEditions,
}) {
  if (catalogTrimestre == null || catalogTrimestre.trim().isEmpty) {
    return false;
  }
  if (activeEditions.isEmpty) return false;
  return activeEditions.any((e) => e.trimestre != catalogTrimestre);
}
