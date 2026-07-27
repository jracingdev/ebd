import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/bible/sample_texts.dart';
import 'package:livro_registro/features/bible/bible_reader_screen.dart';
import 'package:livro_registro/services/bible_repository.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class BiblePlansScreen extends StatelessWidget {
  const BiblePlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<BibleRepository>();

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'Minha leitura'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text(
            'Planos curtos para acompanhar a semana da EBD. '
            'Marque o dia quando terminar a leitura.',
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
          const SizedBox(height: 16),
          for (final plan in repo.plans) ...[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.brown,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plan.description,
                    style: const TextStyle(color: AppColors.muted, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (_) {
                      final progress = repo.progressFor(plan.id);
                      final done = progress.completedDays.length;
                      final total = plan.days.length;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$done de $total dias',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: total == 0 ? 0 : done / total,
                            color: AppColors.green,
                            backgroundColor:
                                AppColors.green.withValues(alpha: 0.15),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  for (final day in plan.days)
                    _PlanDayTile(
                      day: day.day,
                      title: day.title ??
                          '${bookById(day.bookId)?.name ?? day.bookId} ${day.chapter}',
                      bookLabel:
                          '${bookById(day.bookId)?.name ?? day.bookId} ${day.chapter}',
                      done: repo.progressFor(plan.id).completedDays.contains(day.day),
                      onOpen: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BibleReaderScreen(
                              bookId: day.bookId,
                              chapter: day.chapter,
                            ),
                          ),
                        );
                      },
                      onToggle: () => repo.togglePlanDay(plan.id, day.day),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PlanDayTile extends StatelessWidget {
  const _PlanDayTile({
    required this.day,
    required this.title,
    required this.bookLabel,
    required this.done,
    required this.onOpen,
    required this.onToggle,
  });

  final int day;
  final String title;
  final String bookLabel;
  final bool done;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: done,
        activeColor: AppColors.green,
        onChanged: (_) => onToggle(),
      ),
      title: Text('Dia $day · $title'),
      subtitle: Text(bookLabel),
      trailing: IconButton(
        icon: const Icon(Icons.auto_stories_outlined, color: AppColors.gold),
        onPressed: onOpen,
      ),
    );
  }
}
