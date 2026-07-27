import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class StudentsView extends StatelessWidget {
  const StudentsView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final alunos = state.studentsFor(state.selectedGroup);

    return ListView(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alunos da turma',
                  style: Theme.of(context).textTheme.titleLarge),
              Text('${alunos.length} aluno(s) cadastrado(s)',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _add(context),
                child: const Text('+ Adicionar aluno'),
              ),
            ],
          ),
        ),
        if (alunos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nenhum aluno nesta turma ainda.\nCadastre alunos nas turmas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        for (final a in alunos)
          Card(
            child: ListTile(
              title: Text(a.nome),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remover aluno?'),
                      content: Text('Remover ${a.nome} da turma?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Remover')),
                      ],
                    ),
                  );
                  if (ok == true && context.mounted) {
                    await state.removeStudent(a.id);
                  }
                },
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final state = context.read<AppState>();
    final nome = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cadastrar alunos desta turma'),
        content: TextField(
          controller: nome,
          decoration: const InputDecoration(labelText: 'Nome'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true && context.mounted && nome.text.trim().isNotEmpty) {
      await state.addStudent(nome.text, state.selectedGroup);
    }
  }
}
