import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/common.dart';

class AttendanceView extends StatelessWidget {
  const AttendanceView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final grupo = state.selectedGroup;
    final data = lastOrThisSunday();
    final sessions = state.attendance
        .where((a) => a.grupo == grupo)
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    final today = sessions.where((s) => s.data == data).toList();
    final session = today.isEmpty ? null : today.first;
    final alunos = state.studentsFor(grupo);

    if (alunos.isEmpty) {
      return SectionCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Cadastre os alunos da turma para marcar presente/ausente neste domingo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => state.setModeView('alunos'),
              child: const Text('Ir para Alunos'),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatDayDate(data),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (session == null)
                FilledButton(
                  onPressed: () =>
                      state.ensureAttendanceSession(grupo, data),
                  child: const Text('Abrir chamada deste domingo'),
                )
              else
                Text(
                  '${session.presentes} presente(s) / ${session.pessoas.length}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        if (session != null)
          for (final p in session.pessoas)
            SwitchListTile(
              title: Text(p.nome),
              subtitle: Text(p.presente ? 'Presente' : 'Ausente'),
              value: p.presente,
              activeThumbColor: AppColors.green,
              onChanged: (v) => state.setAttendancePresent(
                sessionId: session.id,
                alunoId: p.alunoId ?? p.id,
                presente: v,
              ),
            ),
        if (sessions.length > 1) ...[
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Domingos anteriores',
                style: TextStyle(fontWeight: FontWeight.w700)),
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
