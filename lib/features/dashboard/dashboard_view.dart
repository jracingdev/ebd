import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/common.dart';

/// Abreviação legível para eixos/listas estreitas (nome completo fica na linha).
String groupShortLabel(String grupo) {
  final base = grupo.split('(').first.trim();
  const map = <String, String>{
    'Maternal': 'Maternal',
    'Pré-escolar': 'Pré-esc.',
    'Primários': 'Primários',
    'Juniores': 'Juniores',
    'Adolescentes 12-14': 'Adol. 12-14',
    'Adolescentes 15-17': 'Adol. 15-17',
    'Jovens': 'Jovens',
    'CIBE': 'CIBE',
    'Varões': 'Varões',
  };
  return map[base] ??
      (base.length <= 14 ? base : '${base.substring(0, 12)}…');
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final groups = state.groups;
    final byGroup = <String, int>{
      for (final g in groups) g: state.studentsFor(g).length,
    };
    final maxByGroup =
        byGroup.values.fold<int>(0, (m, v) => v > m ? v : m);

    final pago = state.records
        .where((r) => r.isPago)
        .fold<double>(0, (s, r) => s + r.valor);
    final pendente = state.records
        .where((r) => !r.isPago)
        .fold<double>(0, (s, r) => s + r.valor);
    final ofertas = state.finances
        .where((f) => f.tipo == 'oferta')
        .fold<double>(0, (s, f) => s + f.valor);
    final doacoes = state.finances
        .where((f) => f.tipo == 'doacao')
        .fold<double>(0, (s, f) => s + f.valor);
    final totalArrecadado = pago + ofertas + doacoes;

    final sunday = lastOrThisSunday();
    final sundaySessions =
        state.attendance.where((a) => a.data == sunday).toList();
    final presentesDomingo =
        sundaySessions.fold<int>(0, (s, a) => s + a.presentes);
    final chamadosDomingo =
        sundaySessions.fold<int>(0, (s, a) => s + a.pessoas.length);
    final pctPresenca = chamadosDomingo == 0
        ? null
        : (100.0 * presentesDomingo / chamadosDomingo);

    final theme = Theme.of(context);

    return ListView(
      children: [
        Text('Painel da EBD', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Visão geral de alunos, presença, revistas e finanças.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Indicadores', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _KpiTile(
                    label: 'Alunos',
                    value: '${state.students.length}',
                  ),
                  _KpiTile(
                    label: 'Classes',
                    value: '${groups.length}',
                  ),
                  _KpiTile(
                    label: 'Revistas',
                    value: '${state.records.length}',
                  ),
                  _KpiTile(
                    label: 'Edições',
                    value: '${state.editions.length}',
                  ),
                  _KpiTile(
                    label: 'Presentes',
                    value: sundaySessions.isEmpty
                        ? '—'
                        : '$presentesDomingo',
                    hint: sundaySessions.isEmpty
                        ? 'Sem chamada neste domingo'
                        : formatDayDate(sunday),
                  ),
                  _KpiTile(
                    label: 'Presença %',
                    value: pctPresenca == null
                        ? '—'
                        : '${pctPresenca.round()}%',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Financeiro', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Revistas, ofertas e doações (todas as classes).',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              _MoneyRow(
                label: 'Revistas recebidas',
                value: currency(pago),
                color: AppColors.green,
              ),
              _MoneyRow(
                label: 'Revistas pendentes',
                value: currency(pendente),
                color: AppColors.danger,
              ),
              _MoneyRow(
                label: 'Ofertas',
                value: currency(ofertas),
              ),
              _MoneyRow(
                label: 'Doações',
                value: currency(doacoes),
                color: AppColors.gold,
              ),
              const Divider(height: 20),
              _MoneyRow(
                label: 'Total arrecadado',
                value: currency(totalArrecadado),
                emphasize: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Presença — último domingo',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                formatDayDate(sunday),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (sundaySessions.isEmpty)
                const Text(
                  'Nenhuma chamada registrada neste domingo.',
                  style: TextStyle(color: AppColors.muted),
                )
              else ...[
                Text(
                  '$presentesDomingo presente(s) de $chamadosDomingo '
                  'chamado(s)'
                  '${pctPresenca == null ? '' : ' · ${pctPresenca.round()}%'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                for (final s in (List<AttendanceSession>.from(sundaySessions)
                  ..sort((a, b) => a.grupo.compareTo(b.grupo))))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.grupo,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Text(
                          '${s.presentes}/${s.pessoas.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alunos por classe',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Barras horizontais com nome abreviado; toque para ver o nome completo.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              if (groups.isEmpty)
                const Text(
                  'Nenhuma classe cadastrada.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                for (final g in groups)
                  _ClassBarRow(
                    shortLabel: groupShortLabel(g),
                    fullLabel: g,
                    count: byGroup[g] ?? 0,
                    maxCount: maxByGroup == 0 ? 1 : maxByGroup,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
    if (hint == null) return child;
    return Tooltip(message: hint!, child: child);
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.color,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
      fontSize: emphasize ? 15 : 14,
      color: color ?? AppColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w400,
                fontSize: emphasize ? 15 : 14,
              ),
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ClassBarRow extends StatelessWidget {
  const _ClassBarRow({
    required this.shortLabel,
    required this.fullLabel,
    required this.count,
    required this.maxCount,
  });

  final String shortLabel;
  final String fullLabel;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final fraction = (count / maxCount).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Tooltip(
        message: '$fullLabel · $count aluno(s)',
        child: Row(
          children: [
            SizedBox(
              width: 92,
              child: Text(
                shortLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth * fraction;
                  return Stack(
                    children: [
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.ink.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                        width: w < 2 && count > 0 ? 2 : w,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppColors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 28,
              child: Text(
                '$count',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
