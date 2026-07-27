import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/features/about/about_screen.dart';
import 'package:livro_registro/features/admin/users_admin_screen.dart';
import 'package:livro_registro/features/attendance/attendance_view.dart';
import 'package:livro_registro/features/backup/backup_screen.dart';
import 'package:livro_registro/features/bible/bible_home_screen.dart';
import 'package:livro_registro/features/dashboard/dashboard_view.dart';
import 'package:livro_registro/features/finances/finances_view.dart';
import 'package:livro_registro/features/lessons/lessons_views.dart';
import 'package:livro_registro/features/magazines/magazines_view.dart';
import 'package:livro_registro/features/report/report_pdf.dart';
import 'package:livro_registro/features/students/students_view.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _modes = [
    ('revistas', 'Revistas'),
    ('ofertas', 'Ofertas'),
    ('presenca', 'Presença'),
    ('alunos', 'Alunos'),
    ('painel', 'Painel'),
    ('licoes', 'Lições'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final role = user?.role ?? UserRole.aluno;
    final modes = role.isStaff
        ? _modes
        : _modes.where((m) => m.$1 == 'licoes' || m.$1 == 'presenca').toList();

    if (user?.grupo != null &&
        !role.seesAllClasses &&
        state.selectedGroup != user!.grupo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state.selectGroup(user.grupo!);
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ESCOLA BÍBLICA DOMINICAL',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.gold,
                            letterSpacing: 1.2,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'EBD',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                        ),
                        if (user != null)
                          Text(
                            '${user.nome} · ${role.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (role.isStaff)
                    TextButton(
                      onPressed: () => printEbdReport(context),
                      child: const Text('Relatório'),
                    ),
                  PopupMenuButton<_HomeAction>(
                    tooltip: 'Menu',
                    onSelected: (action) =>
                        _onAction(context, auth, action),
                    itemBuilder: (ctx) => [
                      if (role.canManageUsers)
                        const PopupMenuItem(
                          value: _HomeAction.users,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.manage_accounts_outlined),
                            title: Text('Usuários'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (role.canSyncBetel || role == UserRole.pastor)
                        const PopupMenuItem(
                          value: _HomeAction.lessons,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.menu_book_outlined),
                            title: Text('Lições / Betel'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      if (role.isStaff)
                        const PopupMenuItem(
                          value: _HomeAction.backup,
                          child: ListTile(
                            dense: true,
                            leading: Icon(Icons.cloud_upload_outlined),
                            title: Text('Backup'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: _HomeAction.bible,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.auto_stories_outlined),
                          title: Text('Bíblia EBD'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: _HomeAction.about,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.info_outline),
                          title: Text('Sobre'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: _HomeAction.logout,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.logout),
                          title: Text('Sair'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ),
            if (role == UserRole.aluno || role == UserRole.professor)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LessonTodayCard(
                  lesson: state
                      .lessonTodayFor(user?.grupo ?? state.selectedGroup),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (id, label) in modes)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: state.modeView == id,
                        onSelected: (_) => state.setModeView(id),
                        selectedColor: AppColors.brown,
                        labelStyle: TextStyle(
                          color: state.modeView == id
                              ? Colors.white
                              : AppColors.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (role.seesAllClasses || role == UserRole.professor) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final g in state.groups)
                      if (role.seesAllClasses ||
                          user?.grupo == null ||
                          user?.grupo == g)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onLongPress: role.canManageGroups &&
                                    !isDefaultGroup(g)
                                ? () => _confirmRemoveGroup(context, state, g)
                                : null,
                            child: ChoiceChip(
                              label: Text(g),
                              selected: state.selectedGroup == g,
                              onSelected: (_) => state.selectGroup(g),
                              selectedColor: AppColors.green,
                              labelStyle: TextStyle(
                                color: state.selectedGroup == g
                                    ? Colors.white
                                    : AppColors.ink,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    if (role.canManageGroups)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Nova classe'),
                          onPressed: () => _addGroupDialog(context, state),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: switch (state.modeView) {
                  'ofertas' => const FinancesView(),
                  'presenca' => const AttendanceView(),
                  'alunos' => const StudentsView(),
                  'painel' => const DashboardView(),
                  'licoes' => role.seesAllClasses
                      ? const LessonsByClassPanel()
                      : SingleChildScrollView(
                          child: LessonTodayCard(
                            lesson: state.lessonTodayFor(
                              user?.grupo ?? state.selectedGroup,
                            ),
                          ),
                        ),
                  _ => const MagazinesView(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onAction(
    BuildContext context,
    AuthService auth,
    _HomeAction action,
  ) {
    switch (action) {
      case _HomeAction.users:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const UsersAdminScreen()),
        );
      case _HomeAction.lessons:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LessonsAdminScreen()),
        );
      case _HomeAction.backup:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BackupScreen()),
        );
      case _HomeAction.bible:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BibleHomeScreen()),
        );
      case _HomeAction.about:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        );
      case _HomeAction.logout:
        auth.logout();
    }
  }

  Future<void> _addGroupDialog(BuildContext context, AppState state) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova classe'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nome da turma',
            hintText: 'Ex.: Casais, Discipulado…',
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await state.addGroup(controller.text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Classe "${controller.text.trim()}" criada.'),
      ),
    );
  }

  Future<void> _confirmRemoveGroup(
    BuildContext context,
    AppState state,
    String grupo,
  ) async {
    final hasData = state.groupHasData(grupo);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover classe?'),
        content: Text(
          hasData
              ? 'A classe "$grupo" possui alunos, revistas ou outros dados. '
                  'Remover apenas a deixa de aparecer na lista; os dados '
                  'permanecem no aparelho. Continuar?'
              : 'Remover a classe "$grupo"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final err = await state.removeGroup(grupo, force: true);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? 'Classe "$grupo" removida.')),
    );
  }
}

enum _HomeAction { users, lessons, backup, bible, about, logout }
