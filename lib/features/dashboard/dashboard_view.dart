import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/common.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final byGroup = <String, int>{
      for (final g in kGroups) g: state.studentsFor(g).length,
    };
    final pago = state.records
        .where((r) => r.isPago)
        .fold<double>(0, (s, r) => s + r.valor);
    final pendente = state.records
        .where((r) => !r.isPago)
        .fold<double>(0, (s, r) => s + r.valor);
    final ofertas = state.finances
        .where((f) => f.tipo == 'oferta')
        .fold<double>(0, (s, f) => s + f.valor);

    return ListView(
      children: [
        Text('Painel da EBD', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alunos por classe',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= kGroups.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              kGroups[i].split(' ').first,
                              style: const TextStyle(fontSize: 9),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (var i = 0; i < kGroups.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: (byGroup[kGroups[i]] ?? 0).toDouble(),
                              color: AppColors.green,
                              width: 12,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Resumo de presença / finanças',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Revistas recebidas: ${currency(pago)}'),
              Text('Revistas pendentes: ${currency(pendente)}'),
              Text('em ofertas: ${currency(ofertas)}'),
              Text('Alunos: ${state.students.length}'),
            ],
          ),
        ),
      ],
    );
  }
}
