import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/permissions.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/common.dart';

class AttendanceView extends StatefulWidget {
  const AttendanceView({super.key});

  @override
  State<AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<AttendanceView> {
  String? _syncKey;

  void _ensureSession(AppState state, String grupo, String data) {
    final alunos = state.studentsFor(grupo);
    if (alunos.isEmpty) return;
    final key =
        '$grupo|$data|${alunos.length}|${alunos.map((a) => a.id).join(',')}';
    if (_syncKey == key) return;
    _syncKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      state.ensureAttendanceSession(grupo, data);
    });
  }

  /// Aluno vinculado ao usuário logado (matrícula ou nome).
  Student? _linkedStudent(AppState state, UserProfile user) {
    final mat = user.matricula.trim().toLowerCase();
    final byMat = state.students.where(
      (s) => (s.matricula ?? '').trim().toLowerCase() == mat,
    );
    if (byMat.isNotEmpty) return byMat.first;
    final nome = user.nome.trim().toLowerCase();
    final byName = state.students.where(
      (s) => s.nome.trim().toLowerCase() == nome && s.grupo == user.grupo,
    );
    return byName.isEmpty ? null : byName.first;
  }

  bool _isSelfRow(AttendancePerson p, Student? linked) {
    if (linked == null) return false;
    final key = p.alunoId ?? p.id;
    return key == linked.id ||
        p.nome.trim().toLowerCase() == linked.nome.trim().toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = context.watch<AuthService>().currentUser;
    final canEditClass =
        userHasPermission(user, AppPermission.editAttendance);
    final isAluno = user?.role == UserRole.aluno;
    final linked = (user != null && isAluno && !canEditClass)
        ? _linkedStudent(state, user)
        : null;

    final grupo = state.selectedGroup;
    final data = lastOrThisSunday();
    final sessions = state.attendance
        .where((a) => a.grupo == grupo)
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    final today = sessions.where((s) => s.data == data).toList();
    final session = today.isEmpty ? null : today.first;
    final alunos = state.studentsFor(grupo);

    // Só staff abre/mescla sessão da turma inteira.
    if (canEditClass) {
      _ensureSession(state, grupo, data);
    }

    if (alunos.isEmpty) {
      return ScrollableFill(
        child: Center(
          child: SectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Cadastre os alunos da turma para marcar presente/ausente neste domingo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                if (canEditClass) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => state.setModeView('alunos'),
                    child: const Text('Ir para Alunos'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final visiblePeople = session == null
        ? const <AttendancePerson>[]
        : canEditClass
            ? session.pessoas
            : session.pessoas.where((p) => _isSelfRow(p, linked)).toList();

    return ListView(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatDayDate(data),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                session == null
                    ? (canEditClass
                        ? 'Abrindo chamada… ${alunos.length} aluno(s)'
                        : 'Aguardando o professor abrir a chamada deste domingo.')
                    : canEditClass
                        ? '${session.presentes} presente(s) / ${session.pessoas.length}'
                        : (visiblePeople.isEmpty
                            ? 'Seu nome ainda não está nesta chamada. Peça ao professor para cadastrá-lo com a mesma matrícula.'
                            : (visiblePeople.first.presente
                                ? 'Você está marcado como presente'
                                : 'Você está marcado como ausente')),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (!canEditClass) ...[
                const SizedBox(height: 6),
                Text(
                  linked == null
                      ? 'Modo aluno: somente visualização da própria presença.'
                      : 'Você pode confirmar só a sua presença (não a da turma).',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        if (session != null)
          for (final p in visiblePeople)
            Column(
              children: [
                SwitchListTile(
                  title: Text(p.nome),
                  subtitle: Text(p.presente ? 'Presente' : 'Ausente'),
                  value: p.presente,
                  activeThumbColor: AppColors.green,
                  onChanged: (!canEditClass && linked == null)
                      ? null
                      : (v) {
                          final key = p.alunoId ?? p.id;
                          state.setAttendancePresent(
                            sessionId: session.id,
                            alunoId: key,
                            presente: v,
                          );
                        },
                ),
                if (p.presente)
                  Padding(
                    padding:
                        const EdgeInsets.only(left: 16, right: 8, bottom: 4),
                    child: SwitchListTile(
                      dense: true,
                      title: const Text('Trouxe Bíblia'),
                      value: p.trouxeBiblia,
                      activeThumbColor: AppColors.gold,
                      onChanged: (!canEditClass && linked == null)
                          ? null
                          : (v) {
                              final key = p.alunoId ?? p.id;
                              state.setAttendanceBroughtBible(
                                sessionId: session.id,
                                alunoId: key,
                                trouxeBiblia: v,
                              );
                            },
                    ),
                  ),
              ],
            )
        else if (canEditClass)
          for (final a in alunos)
            SwitchListTile(
              title: Text(a.nome),
              subtitle: const Text('Ausente'),
              value: false,
              activeThumbColor: AppColors.green,
              onChanged: null,
            )
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Quando o professor abrir a chamada, sua presença aparecerá aqui.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        if (canEditClass && sessions.length > 1) ...[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Domingos anteriores',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          for (final s in sessions.where((s) => s.data != data))
            ListTile(
              title: Text(s.data),
              subtitle: Text(
                  '${s.presentes} presente(s) · ${s.ausentes} ausente(s)'),
            ),
        ],
      ],
    );
  }
}
