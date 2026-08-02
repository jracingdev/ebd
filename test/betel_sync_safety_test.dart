import 'package:flutter_test/flutter_test.dart';
import 'package:livro_registro/data/betel_sync_safety.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/betel_sync_service.dart';

void main() {
  test('trimestre civil em agosto é o 3º', () {
    final (tri, year) =
        BetelSyncService.currentTrimester(DateTime(2026, 8, 2));
    expect(tri, 3);
    expect(year, 2026);
  });

  test('resolveCurrentEdition respeita pin e não troca para edição nova', () {
    final oldEd = Edition(
      id: 'old',
      grupo: 'CIBE',
      trimestre: '2º Trimestre 2026',
      criadoEm: DateTime(2026, 4, 1),
    );
    final newEd = Edition(
      id: 'new',
      grupo: 'CIBE',
      trimestre: '3º Trimestre 2026',
      criadoEm: DateTime(2026, 8, 2),
    );
    final records = [
      DeliveryRecord(
        id: 'r1',
        nome: 'Ana',
        grupo: 'CIBE',
        edicaoId: 'old',
        valor: 25,
        status: 'pago',
        data: DateTime(2026, 5, 1),
      ),
    ];

    final resolved = resolveCurrentEdition(
      editions: [oldEd, newEd],
      grupo: 'CIBE',
      pinnedEditionId: 'old',
      records: records,
    );
    expect(resolved?.id, 'old');
    expect(resolved?.trimestre, '2º Trimestre 2026');
  });

  test('sem pin, prefere edição que já tem entregas', () {
    final oldEd = Edition(
      id: 'old',
      grupo: 'CIBE',
      trimestre: '2º Trimestre 2026',
      criadoEm: DateTime(2026, 4, 1),
    );
    final newEd = Edition(
      id: 'new',
      grupo: 'CIBE',
      trimestre: '3º Trimestre 2026',
      criadoEm: DateTime(2026, 8, 2),
    );
    final resolved = resolveCurrentEdition(
      editions: [oldEd, newEd],
      grupo: 'CIBE',
      records: [
        DeliveryRecord(
          id: 'r1',
          nome: 'Ana',
          grupo: 'CIBE',
          edicaoId: 'old',
          valor: 25,
          status: 'pago',
          data: DateTime(2026, 5, 1),
        ),
      ],
    );
    expect(resolved?.id, 'old');
  });

  test('missingEditionsFromCatalog não sugere o que já existe', () {
    final catalog = [
      const BetelCatalogItem(
        grupo: 'CIBE',
        trimestre: '3º Trimestre 2026',
        serie: 'Adulto',
      ),
      const BetelCatalogItem(
        grupo: 'Jovens',
        trimestre: '3º Trimestre 2026',
        serie: 'CONECTAR+',
      ),
    ];
    final editions = [
      Edition(
        id: '1',
        grupo: 'CIBE',
        trimestre: '3º Trimestre 2026',
        criadoEm: DateTime(2026, 8, 1),
      ),
    ];
    final missing = missingEditionsFromCatalog(
      catalog: catalog,
      editions: editions,
    );
    expect(missing.length, 1);
    expect(missing.single.grupo, 'Jovens');
  });

  test('snapshot operacional exige preservar contagens e ids de edição', () {
    final before = OperationalDataSnapshot(
      students: 10,
      records: 5,
      finances: 2,
      attendance: 3,
      lessons: 13,
      editionIds: {'a', 'b'},
    );
    final afterOk = OperationalDataSnapshot(
      students: 10,
      records: 5,
      finances: 2,
      attendance: 3,
      lessons: 13,
      editionIds: {'a', 'b', 'c'}, // novas edições ok
    );
    final afterBad = OperationalDataSnapshot(
      students: 0,
      records: 0,
      finances: 2,
      attendance: 3,
      lessons: 13,
      editionIds: {'c'},
    );
    expect(before.preservedBy(afterOk), isTrue);
    expect(before.preservedBy(afterBad), isFalse);
  });

  test('catalogTrimestreDiffersFromActive detecta mudança de tri', () {
    expect(
      catalogTrimestreDiffersFromActive(
        catalogTrimestre: '3º Trimestre 2026',
        activeEditions: [
          Edition(
            id: '1',
            grupo: 'CIBE',
            trimestre: '2º Trimestre 2026',
            criadoEm: DateTime(2026, 4, 1),
          ),
        ],
      ),
      isTrue,
    );
    expect(
      catalogTrimestreDiffersFromActive(
        catalogTrimestre: '2º Trimestre 2026',
        activeEditions: [
          Edition(
            id: '1',
            grupo: 'CIBE',
            trimestre: '2º Trimestre 2026',
            criadoEm: DateTime(2026, 4, 1),
          ),
        ],
      ),
      isFalse,
    );
  });
}
