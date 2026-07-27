import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/features/attendance/attendance_view.dart';
import 'package:livro_registro/features/backup/backup_screen.dart';
import 'package:livro_registro/features/dashboard/dashboard_view.dart';
import 'package:livro_registro/features/finances/finances_view.dart';
import 'package:livro_registro/features/magazines/magazines_view.dart';
import 'package:livro_registro/features/report/report_pdf.dart';
import 'package:livro_registro/features/students/students_view.dart';
import 'package:livro_registro/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _modes = [
    ('revistas', 'Revistas'),
    ('ofertas', 'Ofertas'),
    ('presenca', 'Presença'),
    ('alunos', 'Alunos'),
    ('painel', 'Painel'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
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
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Backup',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BackupScreen()),
                    ),
                    icon: const Icon(Icons.cloud_upload_outlined),
                  ),
                  FilledButton(
                    onPressed: () => printEbdReport(context),
                    child: const Text('Relatório'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (id, label) in _modes)
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
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final g in kGroups)
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
            const SizedBox(height: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: switch (state.modeView) {
                  'ofertas' => const FinancesView(),
                  'presenca' => const AttendanceView(),
                  'alunos' => const StudentsView(),
                  'painel' => const DashboardView(),
                  _ => const MagazinesView(),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
