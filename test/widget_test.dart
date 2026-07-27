import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/permissions.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/widgets/common.dart';

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

  test('AppBackup includes users list', () {
    final backup = AppBackup(
      version: kBackupVersion,
      exportedAt: DateTime.parse('2026-07-27T12:00:00'),
      editions: const [],
      records: const [],
      finances: const [],
      attendance: const [],
      students: const [],
      users: [
        {
          'id': '1',
          'matricula': 'admin',
          'nome': 'Admin',
          'role': 'admin',
          'ativo': true,
        }
      ],
    );
    final round = AppBackup.fromJson(backup.toJson());
    expect(round.users.single['matricula'], 'admin');
    expect(round.version, kBackupVersion);
  });

  test('UserRole helpers', () {
    expect(UserRole.admin.seesAllClasses, isTrue);
    expect(UserRole.aluno.isStaff, isFalse);
    expect(UserRole.fromString('pastor'), UserRole.pastor);
  });

  test('permission presets and overrides', () {
    final aluno = UserProfile(
      id: 'a',
      matricula: '100',
      nome: 'Aluno',
      role: UserRole.aluno,
    );
    expect(aluno.can(AppPermission.seeFinances), isFalse);
    expect(aluno.can(AppPermission.editAttendance), isTrue);

    final professor = UserProfile(
      id: 'p',
      matricula: '200',
      nome: 'Prof',
      role: UserRole.professor,
      permissionOverrides: {AppPermission.seeFinances.name: true},
    );
    expect(professor.can(AppPermission.seeFinances), isTrue);
    expect(professor.can(AppPermission.seePanel), isFalse);

    final admin = UserProfile(
      id: 'x',
      matricula: 'admin',
      nome: 'Admin',
      role: UserRole.admin,
      permissionOverrides: {AppPermission.seeFinances.name: false},
    );
    expect(admin.can(AppPermission.seeFinances), isTrue);

    final overrides = UserProfilePermissions.overridesFromEffective(
      role: UserRole.professor,
      effective: {
        for (final p in AppPermission.values)
          p.name: rolePermissionPreset(UserRole.professor).contains(p),
        AppPermission.seePanel.name: true,
      },
    );
    expect(overrides?[AppPermission.seePanel.name], isTrue);
  });

  test('Attendance person unique ids', () {
    final a =
        AttendancePerson(id: 'a1', nome: 'A', presente: false, alunoId: 'a1');
    final b =
        AttendancePerson(id: 'b1', nome: 'B', presente: false, alunoId: 'b1');
    expect(a.id == b.id, isFalse);
  });

  testWidgets('placeholder', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('ScrollableFill evita overflow em altura de landscape',
      (tester) async {
    FlutterError.onError = (details) {
      fail('FlutterError: ${details.exceptionAsString()}');
    };
    await tester.binding.setSurfaceSize(const Size(800, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 120),
              Expanded(
                child: ScrollableFill(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Nenhuma revista cadastrada para Maternal ainda.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () {},
                          child: const Text('Cadastrar revista do trimestre'),
                        ),
                        const SizedBox(height: 80),
                        const Text('extra para forçar scroll'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cadastrar revista do trimestre'), findsOneWidget);
  });
}
