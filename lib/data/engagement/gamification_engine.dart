import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/engagement/engagement_models.dart';
import 'package:livro_registro/data/engagement/engagement_store.dart';
import 'package:livro_registro/data/engagement/gamification_rules.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/services/bible_repository.dart';

class StudentScore {
  const StudentScore({
    required this.student,
    required this.points,
    required this.badges,
    required this.breakdown,
  });

  final Student student;
  final int points;
  final Set<String> badges;
  final Map<String, int> breakdown;
}

class ClassOfferRank {
  const ClassOfferRank({
    required this.grupo,
    required this.total,
  });

  final String grupo;
  final double total;
}

/// Calcula placar a partir dos dados locais (presença, revistas, Bíblia, quiz).
class GamificationEngine {
  GamificationEngine({
    required this.state,
    required this.store,
    this.bible,
    this.deviceStudentId,
  });

  final AppState state;
  final EngagementStore store;
  final BibleRepository? bible;

  /// Aluno que recebe créditos de leitura/quiz deste aparelho.
  final String? deviceStudentId;

  List<StudentScore> computeStudentScores({String? onlyGroup}) {
    final students = onlyGroup == null
        ? state.students
        : state.students.where((s) => s.grupo == onlyGroup).toList();

    final scores = <StudentScore>[];
    for (final s in students) {
      final breakdown = <String, int>{};
      var pts = 0;
      final isDeviceUser = deviceStudentId != null && s.id == deviceStudentId;

      var presentes = 0;
      var bibliaCount = 0;
      final presentDates = <String>{};
      for (final session in state.attendance) {
        if (session.grupo != s.grupo) continue;
        for (final p in session.pessoas) {
          final key = p.alunoId ?? p.id;
          final same = key == s.id ||
              p.nome.trim().toLowerCase() == s.nome.trim().toLowerCase();
          if (!same) continue;
          if (p.presente) {
            presentes++;
            presentDates.add(session.data);
            pts += kPtsPresenca;
            breakdown['Presenças'] =
                (breakdown['Presenças'] ?? 0) + kPtsPresenca;
          }
          if (p.trouxeBiblia) {
            bibliaCount++;
            pts += kPtsBibliaNaAula;
            breakdown['Bíblia na aula'] =
                (breakdown['Bíblia na aula'] ?? 0) + kPtsBibliaNaAula;
          }
        }
      }

      final ed = state.currentEdition(s.grupo);
      if (ed != null) {
        final recs = state.records.where(
          (r) =>
              r.edicaoId == ed.id &&
              r.nome.trim().toLowerCase() == s.nome.trim().toLowerCase(),
        );
        for (final r in recs) {
          if (r.isPago) {
            pts += kPtsRevistaPaga;
            breakdown['Revista paga'] =
                (breakdown['Revista paga'] ?? 0) + kPtsRevistaPaga;
            if (r.data.month == DateTime.now().month &&
                r.data.year == DateTime.now().year) {
              pts += kPtsRevistaEmDia;
              breakdown['Revista em dia'] =
                  (breakdown['Revista em dia'] ?? 0) + kPtsRevistaEmDia;
            }
          }
        }
      }

      final completo = s.fotoUrl != null &&
          s.fotoUrl!.isNotEmpty &&
          s.telefone != null &&
          s.telefone!.isNotEmpty &&
          s.aniversario != null;
      if (completo) {
        pts += kPtsCadastroCompleto;
        breakdown['Cadastro completo'] = kPtsCadastroCompleto;
      }

      if (isDeviceUser && bible != null) {
        final chapters = bible!.chaptersReadCount;
        final streak = bible!.readingStreakDays;
        if (chapters > 0) {
          final capped = (chapters * kPtsCapituloLido)
              .clamp(0, kPtsCapituloLidoMaxDia * 60);
          pts += capped;
          breakdown['Leitura Bíblia'] = capped;
        }
        if (streak > 0) {
          final st = streak * kPtsStreakLeituraDia;
          pts += st;
          breakdown['Streak leitura'] = st;
        }
        var planDays = 0;
        for (final p in bible!.planProgress.values) {
          planDays += p.completedDays.length;
        }
        if (planDays > 0) {
          final pPts = planDays * kPtsPlanoLeituraDia;
          pts += pPts;
          breakdown['Plano de leitura'] = pPts;
        }
        for (final best in store.quizBest.values) {
          final qPts = kPtsQuizBase + best.score * kPtsQuizPorAcerto;
          pts += qPts;
          breakdown['Quiz ${best.level.label}'] =
              (breakdown['Quiz ${best.level.label}'] ?? 0) + qPts;
          if (best.level == QuizLevel.expert && best.ratio >= 0.7) {
            pts += kPtsQuizExpertRecorde;
            breakdown['Recorde expert'] = kPtsQuizExpertRecorde;
          }
        }
      }

      final now = DateTime.now();
      final sundaysInMonth = _sundaysInMonth(now.year, now.month);
      final presentThisMonth = presentDates.where((d) {
        final dt = DateTime.tryParse(d);
        return dt != null && dt.year == now.year && dt.month == now.month;
      }).length;
      if (sundaysInMonth > 0 && presentThisMonth >= sundaysInMonth) {
        pts += kPtsPresenca100Mes;
        breakdown['100% mês'] = kPtsPresenca100Mes;
      }

      final badges = <String>{...(store.badgesByStudent[s.id] ?? {})};
      if (presentes >= 1) badges.add(EbdBadges.primeiroPasso);
      if (presentes >= 8) badges.add(EbdBadges.fielPresenca);
      if (bibliaCount >= 4) badges.add(EbdBadges.bibliaNaMao);
      if (isDeviceUser && (bible?.chaptersReadCount ?? 0) >= 30) {
        badges.add(EbdBadges.leitorDedicado);
      }
      if (isDeviceUser && (bible?.readingStreakDays ?? 0) >= 7) {
        badges.add(EbdBadges.streak7);
      }
      if (ed != null &&
          state.records.any(
            (r) =>
                r.edicaoId == ed.id &&
                r.isPago &&
                r.nome.trim().toLowerCase() == s.nome.trim().toLowerCase(),
          )) {
        badges.add(EbdBadges.revistaEmDia);
      }
      if (isDeviceUser && store.quizBest.containsKey(QuizLevel.facil)) {
        badges.add(EbdBadges.quizFacil);
      }
      final expert = store.quizBest[QuizLevel.expert];
      if (isDeviceUser && expert != null && expert.ratio >= 0.7) {
        badges.add(EbdBadges.quizExpert);
      }
      if (completo) badges.add(EbdBadges.cadastroCompleto);
      if (sundaysInMonth > 0 && presentThisMonth >= sundaysInMonth) {
        badges.add(EbdBadges.mesPerfeito);
      }

      final manual = store.pointsByStudent[s.id] ?? 0;
      if (manual != 0) {
        pts += manual;
        breakdown['Bônus'] = manual;
      }

      scores.add(
        StudentScore(
          student: s,
          points: pts,
          badges: badges,
          breakdown: breakdown,
        ),
      );
    }

    scores.sort((a, b) => b.points.compareTo(a.points));
    return scores;
  }

  List<ClassOfferRank> classOfferRanking({DateTime? from, DateTime? to}) {
    final start =
        from ?? DateTime(DateTime.now().year, DateTime.now().month, 1);
    final end = to ?? DateTime.now();
    final totals = <String, double>{};
    for (final f in state.finances) {
      final tipo = f.tipo.toLowerCase();
      if (tipo != 'oferta' && !tipo.contains('oferta')) continue;
      final d = DateTime.tryParse(f.data);
      if (d == null) continue;
      if (d.isBefore(start) || d.isAfter(end)) continue;
      totals[f.grupo] = (totals[f.grupo] ?? 0) + f.valor;
    }
    final list = [
      for (final e in totals.entries)
        ClassOfferRank(grupo: e.key, total: e.value),
    ]..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  static int _sundaysInMonth(int year, int month) {
    final now = DateTime.now();
    var count = 0;
    var d = DateTime(year, month, 1);
    final limit = (year == now.year && month == now.month)
        ? DateTime(now.year, now.month, now.day)
        : DateTime(year, month + 1, 0);
    while (!d.isAfter(limit) && d.month == month) {
      if (d.weekday == DateTime.sunday) count++;
      d = d.add(const Duration(days: 1));
    }
    return count;
  }
}
