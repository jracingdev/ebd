import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/permissions.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/services/betel_sync_service.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class LessonTodayCard extends StatelessWidget {
  const LessonTodayCard({super.key, required this.lesson, this.grupo});

  final Lesson? lesson;
  final String? grupo;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            grupo == null ? 'Lição de hoje' : 'Lição — $grupo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (lesson == null)
            const Text(
              'Nenhuma lição programada para esta data. '
              'Peça ao Admin para cadastrar as 13 lições do trimestre.',
              style: TextStyle(color: AppColors.muted),
            )
          else ...[
            Text(
              'Lição ${lesson!.numero} de 13',
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lesson!.titulo,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class LessonsByClassPanel extends StatelessWidget {
  const LessonsByClassPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final map = state.lessonsTodayByGroup();
    return ListView(
      children: [
        Text('Temas das lições por classe',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
          'Visão do Superintendente / Pastor',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        for (final g in state.groups) ...[
          LessonTodayCard(lesson: map[g], grupo: g),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class LessonsAdminScreen extends StatefulWidget {
  const LessonsAdminScreen({super.key});

  @override
  State<LessonsAdminScreen> createState() => _LessonsAdminScreenState();
}

class _LessonsAdminScreenState extends State<LessonsAdminScreen> {
  String? _editionId;
  final _titles = List.generate(13, (_) => TextEditingController());
  DateTime _start = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Próximo/último domingo
    final now = DateTime.now();
    _start = now.subtract(Duration(days: now.weekday % 7));
  }

  @override
  void dispose() {
    for (final c in _titles) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _syncBetel() async {
    setState(() => _busy = true);
    try {
      final state = context.read<AppState>();
      final n = await state.syncBetelCatalog();
      if (!mounted) return;
      final src = state.lastBetelSyncSource;
      final srcLabel = switch (src) {
        'edge' => 'nuvem (Edge Function)',
        'client' => 'site Betel (neste aparelho)',
        'static' => 'catálogo embutido (fallback)',
        _ => 'desconhecida',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Catálogo Betel: $n itens via $srcLabel.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Falha no sync: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final ed = state.editions.where((e) => e.id == _editionId);
    if (ed.isEmpty) return;
    final sundays = BetelSyncService.thirteenSundays(_start);
    final items = <({int numero, String titulo, DateTime data})>[];
    for (var i = 0; i < 13; i++) {
      final t = _titles[i].text.trim();
      items.add((
        numero: i + 1,
        titulo: t.isEmpty ? 'Lição ${i + 1}' : t,
        data: sundays[i],
      ));
    }
    await state.saveLessonsForEdition(
      editionId: ed.first.id,
      grupo: ed.first.grupo,
      items: items,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('13 lições salvas.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthService>();
    final canSync =
        userHasPermission(auth.currentUser, AppPermission.syncBetel);

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'Lições e Betel'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (canSync) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _syncBetel,
              icon: const Icon(Icons.cloud_sync),
              label: const Text('Atualizar catálogo Editora Betel'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Com Supabase: tenta a Edge Function sync-betel e lê '
              'betel_catalog; se falhar, faz scrape no aparelho.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 16),
          if (state.editions.isEmpty)
            const Text(
              'Nenhuma revista/edição cadastrada ainda. '
              'Cadastre uma revista na aba Revistas ou sincronize o catálogo Betel.',
              style: TextStyle(color: AppColors.muted),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _editionId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Edição / turma',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in state.editions)
                  DropdownMenuItem(
                    value: e.id,
                    child: Text(
                      '${e.grupo} — ${e.trimestre}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _editionId = v),
            ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('1º domingo do trimestre'),
            subtitle: Text(
              '${_start.day.toString().padLeft(2, '0')}/'
              '${_start.month.toString().padLeft(2, '0')}/'
              '${_start.year}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _start,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (d != null) setState(() => _start = d);
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cadastre os títulos das 13 lições (não publicados no site da Betel):',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < 13; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _titles[i],
                decoration: InputDecoration(
                  labelText: 'Lição ${i + 1}',
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          FilledButton(
            onPressed: _editionId == null ? null : _save,
            child: const Text('Salvar 13 lições'),
          ),
        ],
      ),
    );
  }
}
