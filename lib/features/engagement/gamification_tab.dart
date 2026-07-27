import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/engagement/engagement_store.dart';
import 'package:livro_registro/data/engagement/gamification_engine.dart';
import 'package:livro_registro/data/engagement/gamification_rules.dart';
import 'package:livro_registro/features/dashboard/dashboard_analytics.dart';
import 'package:livro_registro/services/bible_repository.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/common.dart';

/// Placar de gamificação e ranking de ofertas por classe.
class GamificationTab extends StatelessWidget {
  const GamificationTab({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final store = context.watch<EngagementStore>();
    final bible = context.watch<BibleRepository>();
    final engine = GamificationEngine(
      state: state,
      store: store,
      bible: bible,
    );
    final scores = engine.computeStudentScores(onlyGroup: state.selectedGroup);
    final offers = engine.classOfferRanking();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Placar — ${groupShortLabel(state.selectedGroup)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Pontos por presença, Bíblia na aula, revistas, quiz e leitura.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              if (scores.isEmpty)
                const Text(
                  'Nenhum aluno nesta turma para ranquear.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                for (var i = 0; i < scores.length; i++)
                  _ScoreTile(rank: i + 1, score: scores[i]),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ofertas por classe (mês)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (offers.isEmpty)
                const Text(
                  'Sem ofertas registradas neste mês.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                for (var i = 0; i < offers.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                      foregroundColor: AppColors.brown,
                      child: Text('${i + 1}'),
                    ),
                    title: Text(groupShortLabel(offers[i].grupo)),
                    trailing: Text(
                      currency(offers[i].total),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.rank, required this.score});

  final int rank;
  final StudentScore score;

  @override
  Widget build(BuildContext context) {
    final badges = score.badges.toList()..sort();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: CircleAvatar(
        backgroundColor: rank <= 3
            ? AppColors.green.withValues(alpha: 0.2)
            : AppColors.muted.withValues(alpha: 0.15),
        foregroundColor: AppColors.ink,
        child: Text('$rank'),
      ),
      title: Text(score.student.nome),
      subtitle: badges.isEmpty
          ? null
          : Text(
              badges
                  .take(3)
                  .map((b) => EbdBadges.labels[b] ?? b)
                  .join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
      trailing: Text(
        '${score.points} pts',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.green,
        ),
      ),
      children: [
        for (final e in score.breakdown.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                Text('+${e.value}', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        if (badges.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in badges)
                Chip(
                  label: Text(
                    EbdBadges.labels[b] ?? b,
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
