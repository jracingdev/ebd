import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/features/dashboard/dashboard_analytics.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/common.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final snap = buildDashboardSnapshot(state);
    final theme = Theme.of(context);
    final maxByGroup = snap.studentsByGroup.values
        .fold<int>(0, (m, v) => v > m ? v : m);

    return ListView(
      children: [
        Text('Painel da EBD', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'Indicadores, gráficos e leituras práticas da Escola.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 16),

        // —— KPIs ——
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
                  _KpiTile(label: 'Alunos', value: '${state.students.length}'),
                  _KpiTile(label: 'Classes', value: '${snap.groups.length}'),
                  _KpiTile(
                      label: 'Revistas', value: '${state.records.length}'),
                  _KpiTile(
                      label: 'Edições', value: '${state.editions.length}'),
                  _KpiTile(
                    label: 'Presentes',
                    value: snap.sundaySessions.isEmpty
                        ? '—'
                        : '${snap.presentesDomingo}',
                    hint: snap.sundaySessions.isEmpty
                        ? 'Sem chamada neste domingo'
                        : formatDayDate(snap.sunday),
                  ),
                  _KpiTile(
                    label: 'Presença %',
                    value: snap.pctPresencaDomingo == null
                        ? '—'
                        : '${snap.pctPresencaDomingo!.round()}%',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // —— Olhar da semana ——
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Olhar da semana', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Alertas e leituras geradas dos dados locais da EBD.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (snap.insights.isEmpty)
                const Text(
                  'Cadastre alunos, presença e finanças para gerar insights.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                for (final line in snap.insights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w700)),
                        Expanded(child: Text(line, style: const TextStyle(height: 1.35))),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // —— Predições ——
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Predições e riscos', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Heurísticas locais (sem nuvem) — média recente × calendário.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              for (final line in snap.predictions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.trending_up,
                            size: 16, color: AppColors.green),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(line,
                              style: const TextStyle(height: 1.35))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // —— Financeiro ——
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
                value: currency(snap.pago),
                color: AppColors.green,
              ),
              _MoneyRow(
                label: 'Revistas pendentes',
                value: currency(snap.pendente),
                color: AppColors.danger,
              ),
              _MoneyRow(label: 'Ofertas', value: currency(snap.ofertas)),
              _MoneyRow(
                label: 'Doações',
                value: currency(snap.doacoes),
                color: AppColors.gold,
              ),
              const Divider(height: 20),
              _MoneyRow(
                label: 'Total arrecadado',
                value: currency(snap.totalArrecadado),
                emphasize: true,
              ),
              if (snap.projectedOfferings != null) ...[
                const SizedBox(height: 4),
                _MoneyRow(
                  label: 'Projeção ofertas (trimestre)',
                  value: currency(snap.projectedOfferings!),
                  color: AppColors.muted,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // —— Gráfico: revistas pago vs pendente ——
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Revistas: pago × pendente',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              if (snap.pago == 0 && snap.pendente == 0)
                const Text(
                  'Sem valores de revistas ainda.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                SizedBox(
                  height: 180,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                            sections: [
                              if (snap.pago > 0)
                                PieChartSectionData(
                                  value: snap.pago,
                                  color: AppColors.green,
                                  title: snap.pago / (snap.pago + snap.pendente) >
                                          0.12
                                      ? '${(100 * snap.pago / (snap.pago + snap.pendente)).round()}%'
                                      : '',
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  radius: 48,
                                ),
                              if (snap.pendente > 0)
                                PieChartSectionData(
                                  value: snap.pendente,
                                  color: AppColors.danger,
                                  title: snap.pendente /
                                              (snap.pago + snap.pendente) >
                                          0.12
                                      ? '${(100 * snap.pendente / (snap.pago + snap.pendente)).round()}%'
                                      : '',
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                  radius: 48,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LegendDot(
                              color: AppColors.green,
                              label: 'Pago\n${currency(snap.pago)}'),
                          const SizedBox(height: 12),
                          _LegendDot(
                              color: AppColors.danger,
                              label: 'Pendente\n${currency(snap.pendente)}'),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // —— Gráfico: ofertas ao longo do tempo ——
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ofertas e doações por semana',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Soma semanal (domingo a sábado) das últimas semanas.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (snap.financeByWeek.isEmpty)
                const Text(
                  'Sem lançamentos de ofertas/doações ainda.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                SizedBox(
                  height: 200,
                  child: _WeeklyFinanceChart(points: snap.financeByWeek),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // —— Presença % por classe ——
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Presença % por classe',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                formatDayDate(snap.sunday),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (snap.attendancePctByGroup.isEmpty)
                const Text(
                  'Nenhuma chamada neste domingo para montar o gráfico.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                SizedBox(
                  height: (snap.attendancePctByGroup.length * 36.0)
                      .clamp(120.0, 320.0),
                  child: _AttendancePctChart(
                    pctByGroup: snap.attendancePctByGroup,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // —— Presença detalhe ——
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Presença — último domingo',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                formatDayDate(snap.sunday),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (snap.sundaySessions.isEmpty)
                const Text(
                  'Nenhuma chamada registrada neste domingo.',
                  style: TextStyle(color: AppColors.muted),
                )
              else ...[
                Text(
                  '${snap.presentesDomingo} presente(s) de ${snap.chamadosDomingo} '
                  'chamado(s)'
                  '${snap.pctPresencaDomingo == null ? '' : ' · ${snap.pctPresencaDomingo!.round()}%'}'
                  ' · tendência: ${snap.attendanceTrendLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                for (final s in (List<AttendanceSession>.from(
                    snap.sundaySessions)
                  ..sort((a, b) => a.grupo.compareTo(b.grupo))))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(s.grupo,
                              style: const TextStyle(fontSize: 13)),
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

        // —— Alunos por classe ——
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alunos por classe', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Barras com abreviação; toque longo/tooltip para o nome completo.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              if (snap.groups.isEmpty)
                const Text(
                  'Nenhuma classe cadastrada.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                for (final g in snap.groups)
                  _ClassBarRow(
                    shortLabel: groupShortLabel(g),
                    fullLabel: g,
                    count: snap.studentsByGroup[g] ?? 0,
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

class _WeeklyFinanceChart extends StatelessWidget {
  const _WeeklyFinanceChart({required this.points});

  final List<WeeklyFinancePoint> points;

  @override
  Widget build(BuildContext context) {
    final maxY = points
        .map((p) => p.total)
        .fold<double>(0, (m, v) => v > m ? v : m);
    final ceiling = maxY <= 0 ? 10.0 : maxY * 1.15;

    return BarChart(
      BarChartData(
        maxY: ceiling,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ceiling / 4,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.ink.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toInt().toString(),
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    points[i].label,
                    style: const TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: points[i].ofertas,
                  color: AppColors.green,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
                BarChartRodData(
                  toY: points[i].doacoes,
                  color: AppColors.gold,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final p = points[group.x];
              final tipo = rodIndex == 0 ? 'Ofertas' : 'Doações';
              return BarTooltipItem(
                '${p.label}\n$tipo: ${currency(rod.toY)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AttendancePctChart extends StatelessWidget {
  const _AttendancePctChart({required this.pctByGroup});

  final Map<String, double> pctByGroup;

  @override
  Widget build(BuildContext context) {
    final entries = pctByGroup.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return BarChart(
      BarChartData(
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (v) => FlLine(
            color: AppColors.ink.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 25,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: const TextStyle(fontSize: 9, color: AppColors.muted),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= entries.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    groupShortLabel(entries[i].key),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value.clamp(0, 100),
                  color: entries[i].value < 60
                      ? AppColors.danger
                      : AppColors.green,
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            ),
        ],
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final e = entries[group.x];
              return BarTooltipItem(
                '${e.key}\n${e.value.round()}%',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, height: 1.25)),
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
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
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
