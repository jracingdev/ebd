import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/user_models.dart';

void main() {
  test('AppBackup roundtrip with student fields', () {
    final json = {
      'version': 4,
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
          'matricula': '1001',
          'telefone': '11999999999',
          'aniversario': '2000-07-27',
        }
      ],
      'lessons': [],
    };
    final backup = AppBackup.fromJson(json);
    expect(backup.students.single.matricula, '1001');
    expect(backup.toJson()['version'], 4);
  });

  test('UserRole helpers', () {
    expect(UserRole.admin.seesAllClasses, isTrue);
    expect(UserRole.aluno.isStaff, isFalse);
    expect(UserRole.fromString('pastor'), UserRole.pastor);
  });

  test('Attendance person unique ids', () {
    final a = AttendancePerson(id: 'a1', nome: 'A', presente: false, alunoId: 'a1');
    final b = AttendancePerson(id: 'b1', nome: 'B', presente: false, alunoId: 'b1');
    expect(a.id == b.id, isFalse);
  });

  testWidgets('placeholder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(find.byType(SizedBox), findsOneWidget);
  });
}
