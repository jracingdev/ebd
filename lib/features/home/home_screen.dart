import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/permissions.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/features/about/about_screen.dart';
import 'package:livro_registro/features/admin/users_admin_screen.dart';
import 'package:livro_registro/features/attendance/attendance_view.dart';
import 'package:livro_registro/features/backup/backup_screen.dart';
import 'package:livro_registro/features/bible/bible_home_screen.dart';
import 'package:livro_registro/features/dashboard/dashboard_view.dart';
import 'package:livro_registro/features/engagement/desafios_ebd_screen.dart';
import 'package:livro_registro/features/finances/finances_view.dart';
import 'package:livro_registro/features/lessons/lessons_views.dart';
import 'package:livro_registro/features/magazines/magazines_view.dart';
import 'package:livro_registro/features/report/report_pdf.dart';
import 'package:livro_registro/features/students/students_view.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _modes = [
    ('revistas', 'Revistas', AppPermission.manageMagazines),
    ('ofertas', 'Ofertas', AppPermission.seeFinances),
    ('presenca', 'Presença', AppPermission.editAttendance),
    ('alunos', 'Alunos', AppPermission.seeStudents),
    ('painel', 'Painel', AppPermission.seePanel),
    ('licoes', 'Lições', AppPermission.manageLessons),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    final role = user?.role ?? UserRole.aluno;
    final can = userHasPermission;

    final modes = <(String, String)>[];
    for (final (id, label, perm) in _modes) {
      if (id == 'licoes') {
        // Aluno/professor sempre veem a lição do dia (leitura).
        if (can(user, perm) ||
            role == UserRole.aluno ||
            role == UserRole.professor) {
          modes.add((id, label));
        }
      } else if (can(user, perm)) {
        modes.add((id, label));
      }
    }
    if (modes.isEmpty) {
      modes.add(('licoes', 'Lições'));
    }

    final seesAll = can(user, AppPermission.seeAllClasses);
    final canManageGroups = can(user, AppPermission.manageGroups);

    if (user?.grupo != null &&
        !seesAll &&
        state.selectedGroup != user!.grupo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state.selectGroup(user.grupo!);
      });
    }

    // Se a aba atual ficou inacessível, volta para a primeira permitida.
    if (!modes.any((m) => m.$1 == state.modeView)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        state.setModeView(modes.first.$1);
      });
    }

    final short = isShortViewport(context);
    final chipH = short ? 36.0 : 40.0;
    final showLessonBanner = !short &&
        (role == UserRole.aluno || role == UserRole.professor);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, short ? 4 : 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!short)
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
                            style: (short
                                    ? Theme.of(context).textTheme.titleLarge
                                    : Theme.of(context)
                                        .textTheme
                                        .headlineMedium)
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
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: short ? 11 : 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (can(user, AppPermission.seeReport))
                      short
                          ? IconButton(
                              tooltip: 'Relatório',
                              onPressed: () => previewEbdReport(context),
                              icon: const Icon(Icons.picture_as_pdf_outlined),
                            )
                          : TextButton(
                              onPressed: () => previewEbdReport(context),
                              child: const Text('Relatório'),
                            ),
                    PopupMenuButton<_HomeAction>(
                      tooltip: 'Menu',
                      onSelected: (action) =>
                          _onAction(context, auth, action),
                      itemBuilder: (ctx) => [
                        if (can(user, AppPermission.manageUsers))
                          const PopupMenuItem(
                            value: _HomeAction.users,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.manage_accounts_outlined),
                              title: Text('Gerenciar perfis'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        if (can(user, AppPermission.manageLessons) ||
                            can(user, AppPermission.syncBetel))
                          const PopupMenuItem(
                            value: _HomeAction.lessons,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.menu_book_outlined),
                              title: Text('Lições / Betel'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        if (can(user, AppPermission.backup))
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
                        if (can(user, AppPermission.seeDesafios)) ...[
                          const PopupMenuItem(
                            value: _HomeAction.sorteios,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.casino_outlined),
                              title: Text('Sorteios'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: _HomeAction.quiz,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.quiz_outlined),
                              title: Text('Quiz bíblico'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: _HomeAction.placar,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.emoji_events_outlined),
                              title: Text('Conquistas / Placar'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
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
              if (showLessonBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: LessonTodayCard(
                    lesson: state
                        .lessonTodayFor(user?.grupo ?? state.selectedGroup),
                  ),
                ),
              SizedBox(height: short ? 4 : 8),
              SizedBox(
                height: chipH,
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
              if (seesAll || role == UserRole.professor) ...[
                SizedBox(height: short ? 4 : 8),
                SizedBox(
                  height: chipH,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final g in state.groups)
                        if (seesAll ||
                            user?.grupo == null ||
                            user?.grupo == g)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onLongPress: canManageGroups &&
                                      !isDefaultGroup(g)
                                  ? () =>
                                      _confirmRemoveGroup(context, state, g)
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
                      if (canManageGroups)
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
              SizedBox(height: short ? 4 : 8),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, short ? 4 : 8, 16, short ? 8 : 16),
                  child: switch (state.modeView) {
                    'ofertas' => const FinancesView(),
                    'presenca' => const AttendanceView(),
                    'alunos' => const StudentsView(),
                    'painel' => const DashboardView(),
                    'licoes' => seesAll || can(user, AppPermission.manageLessons)
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
      case _HomeAction.sorteios:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DesafiosEbdScreen(initialTab: 0),
          ),
        );
      case _HomeAction.quiz:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DesafiosEbdScreen(initialTab: 1),
          ),
        );
      case _HomeAction.placar:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const DesafiosEbdScreen(initialTab: 2),
          ),
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

enum _HomeAction {
  users,
  lessons,
  backup,
  bible,
  sorteios,
  quiz,
  placar,
  about,
  logout,
}
