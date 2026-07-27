import 'dart:math';

import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/engagement/engagement_models.dart';
import 'package:livro_registro/data/engagement/engagement_store.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/utils/format.dart';

/// Monta o pool de alunos e executa o sorteio conforme critérios.
class RaffleEngine {
  RaffleEngine({
    required this.state,
    required this.store,
    this.teacherNames = const {},
  });

  final AppState state;
  final EngagementStore store;
  final Set<String> teacherNames;

  List<Student> buildPool({
    required Set<String> groups,
    required RaffleCriteria criteria,
  }) {
    var pool = state.students.where((s) => groups.contains(s.grupo)).toList();

    if (criteria.excludeTeachers && teacherNames.isNotEmpty) {
      final lower = teacherNames.map((e) => e.toLowerCase()).toSet();
      pool = pool
          .where((s) => !lower.contains(s.nome.trim().toLowerCase()))
          .toList();
    }

    if (criteria.requireMatriculaOrPhone) {
      pool = pool
          .where(
            (s) =>
                (s.matricula != null && s.matricula!.trim().isNotEmpty) ||
                (s.telefone != null && s.telefone!.trim().isNotEmpty),
          )
          .toList();
    }

    if (criteria.onlyBirthdayMonth) {
      final month = DateTime.now().month;
      pool = pool
          .where(
            (s) => s.aniversario != null && s.aniversario!.month == month,
          )
          .toList();
    }

    if (criteria.onlyPresentOnDate) {
      final date = criteria.attendanceDate ?? lastOrThisSunday();
      final presentIds = <String>{};
      for (final session in state.attendance) {
        if (!groups.contains(session.grupo)) continue;
        if (session.data != date) continue;
        for (final p in session.pessoas) {
          if (p.presente) presentIds.add(p.alunoId ?? p.id);
        }
      }
      pool = pool.where((s) => presentIds.contains(s.id)).toList();
    }

    if (criteria.onlyMagazinePaid || criteria.onlyMagazinePending) {
      pool = pool.where((s) {
        final ed = state.currentEdition(s.grupo);
        if (ed == null) return false;
        final recs = state.records.where(
          (r) =>
              r.edicaoId == ed.id &&
              (r.nome.trim().toLowerCase() == s.nome.trim().toLowerCase() ||
                  (state.students.any(
                        (st) =>
                            st.id == s.id &&
                            r.nome.trim().toLowerCase() ==
                                st.nome.trim().toLowerCase(),
                      ))),
        );
        final mine = recs.isEmpty
            ? null
            : recs.reduce((a, b) => a.data.isAfter(b.data) ? a : b);
        if (mine == null) {
          return criteria.onlyMagazinePending;
        }
        if (criteria.onlyMagazinePaid) return mine.isPago;
        if (criteria.onlyMagazinePending) return !mine.isPago;
        return true;
      }).toList();
    }

    if (criteria.excludePreviousWinners) {
      final tri = currentTrimestreKey();
      final won = store.winnerIdsInTrimestre(tri);
      pool = pool.where((s) => !won.contains(s.id)).toList();
    }

    return pool;
  }

  List<RaffleWinner> draw({
    required Set<String> groups,
    required RaffleCriteria criteria,
    Random? random,
  }) {
    final rng = random ?? Random();
    final pool = buildPool(groups: groups, criteria: criteria);
    if (pool.isEmpty) return [];

    if (criteria.onePerClass) {
      final winners = <RaffleWinner>[];
      for (final g in groups) {
        final classPool = pool.where((s) => s.grupo == g).toList();
        if (classPool.isEmpty) continue;
        final pick = classPool[rng.nextInt(classPool.length)];
        winners.add(
          RaffleWinner(studentId: pick.id, nome: pick.nome, grupo: pick.grupo),
        );
      }
      return winners;
    }

    final shuffled = [...pool]..shuffle(rng);
    final n = criteria.winnerCount.clamp(1, shuffled.length);
    return [
      for (final s in shuffled.take(n))
        RaffleWinner(studentId: s.id, nome: s.nome, grupo: s.grupo),
    ];
  }

  static Set<String> teacherNamesFromUsers(Iterable<UserProfile> users) {
    return {
      for (final u in users)
        if (u.role == UserRole.professor ||
            u.role == UserRole.superintendente ||
            u.role == UserRole.pastor ||
            u.role == UserRole.admin)
          u.nome.trim(),
    };
  }
}
