import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/features/attendance/attendance_view.dart';
import 'package:livro_registro/features/backup/backup_screen.dart';
import 'package:livro_registro/features/dashboard/dashboard_view.dart';
import 'package:livro_registro/features/finances/finances_view.dart';
import 'package:livro_registro/features/lessons/lessons_views.dart';
import 'package:livro_registro/features/magazines/magazines_view.dart';
import 'package:livro_registro/features/report/report_pdf.dart';
import 'package:livro_registro/features/students/students_view.dart';
import 'package:livro_registro/features/admin/users_admin_screen.dart';
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

    // Aluno/professor: força grupo do perfil quando existir
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
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ESCOLA BÍBLICA DOMINICAL',
                          style: TextStyle(
                            color: AppColors.gold,
                            letterSpacing: 1.6,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'EBD',
                          style:
                              Theme.of(context).textTheme.displaySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (user != null)
                          Text(
                            '${user.nome} · ${role.label}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (role.canManageUsers)
                    IconButton(
                      tooltip: 'Usuários',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UsersAdminScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.manage_accounts_outlined),
                    ),
                  if (role.canSyncBetel || role == UserRole.pastor)
                    IconButton(
                      tooltip: 'Lições / Betel',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LessonsAdminScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                  if (role.isStaff)
                    IconButton(
                      tooltip: 'Backup',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BackupScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.cloud_upload_outlined),
                    ),
                  if (role.isStaff)
                    FilledButton(
                      onPressed: () => printEbdReport(context),
                      child: const Text('Relatório'),
                    ),
                  IconButton(
                    tooltip: 'Sair',
                    onPressed: () => auth.logout(),
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
            ),
            if (role == UserRole.aluno || role == UserRole.professor)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: LessonTodayCard(
                  lesson: state.lessonTodayFor(user?.grupo ?? state.selectedGroup),
                ),
              ),
            if (role.seesAllClasses && state.modeView == 'licoes')
              const Expanded(child: Padding(
                padding: EdgeInsets.all(16),
                child: LessonsByClassPanel(),
              ))
            else ...[
              const SizedBox(height: 12),
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
                      for (final g in kGroups)
                        if (role.seesAllClasses || user?.grupo == null || user?.grupo == g)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
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
                    'licoes' => LessonTodayCard(
                        lesson: state.lessonTodayFor(
                          user?.grupo ?? state.selectedGroup,
                        ),
                      ),
                    _ => const MagazinesView(),
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
