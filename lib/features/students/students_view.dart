import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
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
                onPressed: () => _openForm(context),
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
              onTap: () => _openForm(context, existing: a),
              leading: CircleAvatar(
                backgroundImage:
                    a.fotoUrl != null ? _imageProvider(a.fotoUrl!) : null,
                child: a.fotoUrl == null
                    ? Text(a.nome.isEmpty ? '?' : a.nome[0].toUpperCase())
                    : null,
              ),
              title: Text(a.nome),
              subtitle: Text([
                if (a.matricula != null) 'Mat. ${a.matricula}',
                if (a.telefone != null) a.telefone!,
                if (a.aniversario != null)
                  'Aniv. ${a.aniversario!.day}/${a.aniversario!.month}',
                if (a.isBirthdayToday) '🎉 Hoje!',
              ].where((e) => e.isNotEmpty).join(' · ')),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openForm(context, existing: a),
                  ),
                  IconButton(
                    tooltip: 'Remover',
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
                ],
              ),
            ),
          ),
      ],
    );
  }

  ImageProvider? _imageProvider(String path) {
    if (path.startsWith('http')) return NetworkImage(path);
    if (!kIsWeb) return FileImage(File(path));
    return null;
  }

  Future<void> _openForm(BuildContext context, {Student? existing}) async {
    final state = context.read<AppState>();
    final nome = TextEditingController(text: existing?.nome ?? '');
    final matricula = TextEditingController(text: existing?.matricula ?? '');
    final telefone = TextEditingController(text: existing?.telefone ?? '');
    DateTime? aniversario = existing?.aniversario;
    String? fotoPath = existing?.fotoUrl;
    var grupo = existing?.grupo ?? state.selectedGroup;
    if (!state.groups.contains(grupo)) {
      grupo = state.selectedGroup;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Cadastrar aluno' : 'Editar aluno'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final source = await showModalBottomSheet<ImageSource>(
                      context: ctx,
                      builder: (sheet) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_camera),
                              title: const Text('Selfie / câmera'),
                              onTap: () =>
                                  Navigator.pop(sheet, ImageSource.camera),
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Galeria'),
                              onTap: () =>
                                  Navigator.pop(sheet, ImageSource.gallery),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (source == null) return;
                    final file = await ImagePicker()
                        .pickImage(source: source, imageQuality: 75);
                    if (file != null) setLocal(() => fotoPath = file.path);
                  },
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.green.withValues(alpha: 0.15),
                    backgroundImage: fotoPath == null
                        ? null
                        : (kIsWeb ? null : FileImage(File(fotoPath!))),
                    child: fotoPath == null
                        ? const Icon(Icons.add_a_photo_outlined)
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nome,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  autofocus: existing == null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  key: ValueKey(grupo),
                  initialValue:
                      state.groups.contains(grupo) ? grupo : state.groups.first,
                  decoration: const InputDecoration(labelText: 'Classe / turma'),
                  items: [
                    for (final g in state.groups)
                      DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => grupo = v);
                  },
                ),
                TextField(
                  controller: matricula,
                  decoration: const InputDecoration(labelText: 'Matrícula'),
                ),
                TextField(
                  controller: telefone,
                  decoration: const InputDecoration(labelText: 'Telefone'),
                  keyboardType: TextInputType.phone,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    aniversario == null
                        ? 'Data de aniversário'
                        : '${aniversario!.day}/${aniversario!.month}/${aniversario!.year}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (aniversario != null)
                        IconButton(
                          tooltip: 'Limpar',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setLocal(() => aniversario = null),
                        ),
                      const Icon(Icons.cake_outlined),
                    ],
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: aniversario ?? DateTime(2010, 1, 1),
                      firstDate: DateTime(1940),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setLocal(() => aniversario = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !context.mounted) return;
    final nomeTrim = nome.text.trim();
    if (nomeTrim.isEmpty) return;

    final mat = matricula.text.trim();
    final tel = telefone.text.trim();

    if (existing == null) {
      await state.addStudent(
        nome: nomeTrim,
        grupo: grupo,
        matricula: mat,
        telefone: tel,
        aniversario: aniversario,
        fotoUrl: fotoPath,
      );
    } else {
      await state.updateStudent(
        existing.copyWith(
          nome: nomeTrim,
          grupo: grupo,
          matricula: mat,
          telefone: tel,
          aniversario: aniversario,
          fotoUrl: fotoPath,
          clearMatricula: mat.isEmpty,
          clearTelefone: tel.isEmpty,
          clearAniversario: aniversario == null,
          clearFotoUrl: fotoPath == null || fotoPath!.trim().isEmpty,
        ),
      );
    }
  }
}
