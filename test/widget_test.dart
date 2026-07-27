import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_registro/data/models.dart';

void main() {
  test('AppBackup roundtrip', () {
    final json = {
      'version': 3,
      'exportedAt': '2026-07-26T10:33:22.360878',
      'editions': [],
      'records': [],
      'finances': [],
      'attendance': [],
      'students': [
        {
          'id': 'abc',
          'nome': 'Teste',
          'grupo': 'CIBE',
          'criadoEm': '2026-07-26T10:33:22.360878',
        }
      ],
    };
    final backup = AppBackup.fromJson(json);
    expect(backup.students.single.nome, 'Teste');
    expect(backup.toJson()['version'], 3);
  });

  testWidgets('placeholder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
