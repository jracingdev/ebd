import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/utils/format.dart';

/// Snapshot calculado localmente a partir do [AppState] para o Painel.
class DashboardSnapshot {
  const DashboardSnapshot({
    required this.groups,
    required this.studentsByGroup,
    required this.pago,
    required this.pendente,
    required this.ofertas,
    required this.doacoes,
    required this.sunday,
    required this.sundaySessions,
    required this.financeByWeek,
    required this.attendancePctByGroup,
    required this.pendingPctByGroup,
    required this.insights,
    required this.predictions,
    required this.attendanceTrendLabel,
    required this.projectedOfferings,
    required this.remainingSundays,
    required this.avgWeeklyOfferings,
  });

  final List<String> groups;
  final Map<String, int> studentsByGroup;
  final double pago;
  final double pendente;
  final double ofertas;
  final double doacoes;
  final String sunday;
  final List<AttendanceSession> sundaySessions;
  final List<WeeklyFinancePoint> financeByWeek;
  final Map<String, double> attendancePctByGroup;
  final Map<String, double> pendingPctByGroup;
  final List<String> insights;
  final List<String> predictions;
  final String attendanceTrendLabel;
  final double? projectedOfferings;
  final int remainingSundays;
  final double avgWeeklyOfferings;

  double get totalArrecadado => pago + ofertas + doacoes;
  int get presentesDomingo =>
      sundaySessions.fold(0, (s, a) => s + a.presentes);
  int get chamadosDomingo =>
      sundaySessions.fold(0, (s, a) => s + a.pessoas.length);
  double? get pctPresencaDomingo => chamadosDomingo == 0
      ? null
      : 100.0 * presentesDomingo / chamadosDomingo;
}

class WeeklyFinancePoint {
  const WeeklyFinancePoint({
    required this.weekStart,
    required this.ofertas,
    required this.doacoes,
  });

  final DateTime weekStart;
  final double ofertas;
  final double doacoes;

  double get total => ofertas + doacoes;
  String get label {
    final d = weekStart.day.toString().padLeft(2, '0');
    final m = weekStart.month.toString().padLeft(2, '0');
    return '$d/$m';
  }
}

DashboardSnapshot buildDashboardSnapshot(AppState state) {
  final groups = state.groups;
  final studentsByGroup = <String, int>{
    for (final g in groups) g: state.studentsFor(g).length,
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
  final doacoes = state.finances
      .where((f) => f.tipo == 'doacao')
      .fold<double>(0, (s, f) => s + f.valor);

  final sunday = lastOrThisSunday();
  final sundaySessions =
      state.attendance.where((a) => a.data == sunday).toList();

  final financeByWeek = _financeByWeek(state.finances);
  final attendancePctByGroup = _attendancePctByGroup(sundaySessions, groups);
  final pendingPctByGroup = _pendingPctByGroup(state.records, groups);

  final remaining = _remainingSundaysInQuarter(DateTime.now());
  final avgWeekly = _avgWeeklyOfferings(financeByWeek);
  final projected =
      financeByWeek.isEmpty ? null : avgWeekly * remaining;

  final attendanceTrend = _attendanceTrend(state.attendance);
  final insights = _buildInsights(
    state: state,
    groups: groups,
    pago: pago,
    pendente: pendente,
    ofertas: ofertas,
    doacoes: doacoes,
    pendingPctByGroup: pendingPctByGroup,
    attendancePctByGroup: attendancePctByGroup,
    financeByWeek: financeByWeek,
    attendanceTrend: attendanceTrend,
    sundaySessions: sundaySessions,
  );
  final predictions = _buildPredictions(
    remaining: remaining,
    avgWeekly: avgWeekly,
    projected: projected,
    pendingPctByGroup: pendingPctByGroup,
    attendanceTrend: attendanceTrend,
    pendente: pendente,
    pago: pago,
  );

  return DashboardSnapshot(
    groups: groups,
    studentsByGroup: studentsByGroup,
    pago: pago,
    pendente: pendente,
    ofertas: ofertas,
    doacoes: doacoes,
    sunday: sunday,
    sundaySessions: sundaySessions,
    financeByWeek: financeByWeek,
    attendancePctByGroup: attendancePctByGroup,
    pendingPctByGroup: pendingPctByGroup,
    insights: insights,
    predictions: predictions,
    attendanceTrendLabel: attendanceTrend,
    projectedOfferings: projected,
    remainingSundays: remaining,
    avgWeeklyOfferings: avgWeekly,
  );
}

List<WeeklyFinancePoint> _financeByWeek(List<FinanceEntry> finances) {
  if (finances.isEmpty) return const [];
  final map = <DateTime, ({double o, double d})>{};
  for (final f in finances) {
    final day = DateTime.tryParse('${f.data}T12:00:00');
    if (day == null) continue;
    final week = day.subtract(Duration(days: day.weekday % 7));
    final key = DateTime(week.year, week.month, week.day);
    final cur = map[key] ?? (o: 0.0, d: 0.0);
    map[key] = f.tipo == 'oferta'
        ? (o: cur.o + f.valor, d: cur.d)
        : (o: cur.o, d: cur.d + f.valor);
  }
  final keys = map.keys.toList()..sort();
  // Últimas 8 semanas com dados (ou preenchidas se poucas).
  final last = keys.length > 8 ? keys.sublist(keys.length - 8) : keys;
  return [
    for (final k in last)
      WeeklyFinancePoint(
        weekStart: k,
        ofertas: map[k]!.o,
        doacoes: map[k]!.d,
      ),
  ];
}

Map<String, double> _attendancePctByGroup(
  List<AttendanceSession> sessions,
  List<String> groups,
) {
  final out = <String, double>{};
  for (final g in groups) {
    final s = sessions.where((a) => a.grupo == g).toList();
    if (s.isEmpty) continue;
    final total = s.fold<int>(0, (n, a) => n + a.pessoas.length);
    if (total == 0) continue;
    final present = s.fold<int>(0, (n, a) => n + a.presentes);
    out[g] = 100.0 * present / total;
  }
  return out;
}

Map<String, double> _pendingPctByGroup(
  List<DeliveryRecord> records,
  List<String> groups,
) {
  final out = <String, double>{};
  for (final g in groups) {
    final items = records.where((r) => r.grupo == g).toList();
    if (items.isEmpty) continue;
    final total = items.fold<double>(0, (s, r) => s + r.valor);
    if (total <= 0) continue;
    final pend =
        items.where((r) => !r.isPago).fold<double>(0, (s, r) => s + r.valor);
    out[g] = 100.0 * pend / total;
  }
  return out;
}

int _remainingSundaysInQuarter(DateTime now) {
  final q = ((now.month - 1) ~/ 3) + 1;
  final endMonth = q * 3;
  final end = DateTime(now.year, endMonth + 1, 0); // last day of quarter
  var d = DateTime(now.year, now.month, now.day);
  // próximo domingo inclusive se hoje for domingo
  final toSun = d.weekday % 7;
  if (toSun != 0) d = d.add(Duration(days: 7 - toSun));
  var count = 0;
  while (!d.isAfter(end)) {
    count++;
    d = d.add(const Duration(days: 7));
  }
  return count;
}

double _avgWeeklyOfferings(List<WeeklyFinancePoint> weeks) {
  if (weeks.isEmpty) return 0;
  final take = weeks.length >= 4 ? weeks.sublist(weeks.length - 4) : weeks;
  final sum = take.fold<double>(0, (s, w) => s + w.total);
  return sum / take.length;
}

/// Compara média de presença das 2 datas mais recentes vs as 2 anteriores.
String _attendanceTrend(List<AttendanceSession> attendance) {
  if (attendance.isEmpty) return 'sem dados';
  final byDate = <String, List<AttendanceSession>>{};
  for (final a in attendance) {
    byDate.putIfAbsent(a.data, () => []).add(a);
  }
  final dates = byDate.keys.toList()..sort();
  if (dates.length < 2) return 'estável (poucos domingos)';

  double pctFor(List<String> ds) {
    var present = 0;
    var total = 0;
    for (final d in ds) {
      for (final s in byDate[d]!) {
        present += s.presentes;
        total += s.pessoas.length;
      }
    }
    if (total == 0) return 0;
    return 100.0 * present / total;
  }

  final recent = dates.length >= 2
      ? dates.sublist(dates.length - 2)
      : dates;
  final older = dates.length >= 4
      ? dates.sublist(dates.length - 4, dates.length - 2)
      : dates.sublist(0, dates.length - recent.length);
  if (older.isEmpty) return 'estável (poucos domingos)';

  final r = pctFor(recent);
  final o = pctFor(older);
  final delta = r - o;
  if (delta >= 3) return 'subindo (+${delta.round()} p.p.)';
  if (delta <= -3) return 'caindo (${delta.round()} p.p.)';
  return 'estável';
}

List<String> _buildInsights({
  required AppState state,
  required List<String> groups,
  required double pago,
  required double pendente,
  required double ofertas,
  required double doacoes,
  required Map<String, double> pendingPctByGroup,
  required Map<String, double> attendancePctByGroup,
  required List<WeeklyFinancePoint> financeByWeek,
  required String attendanceTrend,
  required List<AttendanceSession> sundaySessions,
}) {
  final out = <String>[];

  if (pendingPctByGroup.isNotEmpty) {
    final worst = pendingPctByGroup.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = worst.first;
    if (top.value >= 20) {
      out.add(
        'Classe ${groupShortLabel(top.key)} com maior pendência de revistas '
        '(${top.value.round()}% do valor). Vale um contato pastoral.',
      );
    } else if (pendente > 0) {
      out.add(
        'Pendências de revistas em ${currency(pendente)} — '
        'nenhuma turma acima de 20%, situação controlada.',
      );
    }
  } else if (state.records.isEmpty) {
    out.add(
      'Ainda não há revistas lançadas. Cadastre a edição do trimestre '
      'para acompanhar recebimentos.',
    );
  }

  if (financeByWeek.length >= 2) {
    final last = financeByWeek.last.total;
    final prev = financeByWeek[financeByWeek.length - 2].total;
    if (prev > 0) {
      final pct = ((last - prev) / prev) * 100;
      final sinal = pct >= 0 ? '+' : '';
      out.add(
        'Ofertas e doações $sinal${pct.round()}% na última semana '
        'em relação à anterior (${currency(last)} vs ${currency(prev)}).',
      );
    } else if (last > 0) {
      out.add(
        'Ofertas e doações recomeçaram na última semana: ${currency(last)}.',
      );
    }
  } else if (ofertas + doacoes > 0) {
    out.add(
      'Arrecadação em ofertas/doações: ${currency(ofertas + doacoes)} '
      '(histórico ainda curto para tendência).',
    );
  }

  if (sundaySessions.isNotEmpty) {
    final best = attendancePctByGroup.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (best.isNotEmpty) {
      out.add(
        'No último domingo, ${groupShortLabel(best.first.key)} '
        'liderou a presença (${best.first.value.round()}%).',
      );
    }
    final low = attendancePctByGroup.entries
        .where((e) => e.value < 60)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    if (low.isNotEmpty) {
      out.add(
        'Atenção: ${groupShortLabel(low.first.key)} com presença baixa '
        '(${low.first.value.round()}%) — verificar faltas recorrentes.',
      );
    }
  } else {
    out.add(
      'Sem chamada neste domingo ainda. Registrar presença ajuda a '
      'acompanhar a vida da Escola.',
    );
  }

  out.add('Tendência de presença: $attendanceTrend.');

  final emptyClasses =
      groups.where((g) => (state.studentsFor(g).isEmpty)).length;
  if (emptyClasses > 0 && state.students.isNotEmpty) {
    out.add(
      '$emptyClasses classe(s) sem alunos cadastrados — '
      'complete o cadastro para chamadas e revistas.',
    );
  }

  // Máx. 6 insights úteis.
  return out.take(6).toList();
}

List<String> _buildPredictions({
  required int remaining,
  required double avgWeekly,
  required double? projected,
  required Map<String, double> pendingPctByGroup,
  required String attendanceTrend,
  required double pendente,
  required double pago,
}) {
  final out = <String>[];

  if (projected != null && avgWeekly > 0) {
    out.add(
      'Projeção de ofertas/doações até o fim do trimestre: '
      '${currency(projected)} '
      '(média ${currency(avgWeekly)}/semana × $remaining domingo(s)).',
    );
  } else {
    out.add(
      'Projeção de arrecadação: lance ofertas em alguns domingos '
      'para estimar o restante do trimestre.',
    );
  }

  final risky = pendingPctByGroup.entries
      .where((e) => e.value >= 35)
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (risky.isNotEmpty) {
    final names = risky.take(2).map((e) => groupShortLabel(e.key)).join(', ');
    out.add(
      'Risco de inadimplência elevado em: $names. '
      'Priorize cobrança amigável e parcelamento se preciso.',
    );
  } else if (pendente > 0 && pago > 0) {
    final pct = 100 * pendente / (pago + pendente);
    out.add(
      'Risco geral de inadimplência moderado '
      '(${pct.round()}% do valor de revistas ainda pendente).',
    );
  } else if (pendente == 0 && pago > 0) {
    out.add('Revistas em dia: nenhuma pendência financeira registrada.');
  }

  if (attendanceTrend.startsWith('caindo')) {
    out.add(
      'Presença em queda — considere visita ou mensagem às famílias '
      'das turmas com mais ausências.',
    );
  } else if (attendanceTrend.startsWith('subindo')) {
    out.add(
      'Presença em alta — bom momento para fortalecer o acompanhamento '
      'das lições e o acolhimento de visitantes.',
    );
  }

  return out.take(4).toList();
}

/// Abreviação legível para eixos/listas estreitas.
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
