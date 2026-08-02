import 'package:flutter/foundation.dart';
import 'package:livro_registro/config/app_config.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de uma sincronização EBD ↔ Supabase.
class CloudSyncResult {
  const CloudSyncResult({
    required this.pushedStudents,
    required this.pulledStudents,
    required this.pushedAttendance,
    required this.pulledAttendance,
    required this.pushedFinances,
    required this.pulledFinances,
    this.warnings = const [],
  });

  final int pushedStudents;
  final int pulledStudents;
  final int pushedAttendance;
  final int pulledAttendance;
  final int pushedFinances;
  final int pulledFinances;
  final List<String> warnings;

  String get summary {
    final parts = <String>[
      'alunos ↑$pushedStudents ↓$pulledStudents',
      'presença ↑$pushedAttendance ↓$pulledAttendance',
      'ofertas ↑$pushedFinances ↓$pulledFinances',
    ];
    if (warnings.isNotEmpty) {
      parts.add('${warnings.length} aviso(s)');
    }
    return parts.join(' · ');
  }
}

/// Sync mínimo e **não destrutivo** de students, attendance e finances.
///
/// **PAUSADO (2026-08-02):** sync de `editions` / Betel — incident com troca de
/// trimestre e perda de dados. Reativar só após hot-fix Betel e com merge
/// estritamente aditivo (nunca wipe/replace).
///
/// Lessons, delivery_records, engagement e Betel ficam para depois.
class CloudSyncService {
  CloudSyncService();

  /// Flag explícita: editions fora do sync até liberação pós-Betel.
  static const bool syncEditionsEnabled = false;

  bool get available => AppConfig.supabaseConfigured;

  SupabaseClient get _client => Supabase.instance.client;

  Future<CloudSyncResult> syncAll(AppState state) async {
    if (!available) {
      throw StateError(
        'Supabase não configurado. Preencha SUPABASE_URL e SUPABASE_ANON_KEY.',
      );
    }
    final session = _client.auth.currentSession;
    if (session == null) {
      throw StateError('Faça login com Supabase para sincronizar.');
    }

    final warnings = <String>[
      if (!syncEditionsEnabled)
        'edições/Betel: sync pausado (aguardando hot-fix não-destrutivo)',
    ];
    var pushedStudents = 0;
    var pulledStudents = 0;
    var pushedAttendance = 0;
    var pulledAttendance = 0;
    var pushedFinances = 0;
    var pulledFinances = 0;

    try {
      pushedStudents = await _pushStudents(state);
      final remoteStudents = await _pullStudents();
      pulledStudents = remoteStudents.length;
      await state.applyCloudStudents(remoteStudents);
    } catch (e) {
      warnings.add('students: $e');
      debugPrint('CloudSync students: $e');
    }

    try {
      pushedFinances = await _pushFinances(state);
      final remoteFinances = await _pullFinances();
      pulledFinances = remoteFinances.length;
      await state.applyCloudFinances(remoteFinances);
    } catch (e) {
      warnings.add('finances: $e');
      debugPrint('CloudSync finances: $e');
    }

    // editions: intencionalmente omitido — ver syncEditionsEnabled.

    try {
      pushedAttendance = await _pushAttendance(state);
      final remoteAttendance = await _pullAttendance();
      pulledAttendance = remoteAttendance.length;
      await state.applyCloudAttendance(remoteAttendance);
    } catch (e) {
      warnings.add('attendance: $e');
      debugPrint('CloudSync attendance: $e');
    }

    try {
      await _pushCustomGroups(state);
    } catch (e) {
      warnings.add('custom_groups: $e');
    }

    return CloudSyncResult(
      pushedStudents: pushedStudents,
      pulledStudents: pulledStudents,
      pushedAttendance: pushedAttendance,
      pulledAttendance: pulledAttendance,
      pushedFinances: pushedFinances,
      pulledFinances: pulledFinances,
      warnings: warnings,
    );
  }

  Future<int> _pushStudents(AppState state) async {
    if (state.students.isEmpty) return 0;
    final rows = state.students
        .map(
          (s) => {
            'id': s.id,
            'nome': s.nome,
            'grupo': s.grupo,
            'matricula': s.matricula,
            'telefone': s.telefone,
            'aniversario': s.aniversario?.toIso8601String().split('T').first,
            'foto_url': s.fotoUrl,
            'criado_em': s.criadoEm.toIso8601String(),
          },
        )
        .toList();
    await _client.from('students').upsert(rows);
    return rows.length;
  }

  Future<List<Student>> _pullStudents() async {
    final data = await _client.from('students').select();
    return (data as List)
        .map((e) => Student.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> _pushFinances(AppState state) async {
    if (state.finances.isEmpty) return 0;
    final rows = state.finances
        .map(
          (f) => {
            'id': f.id,
            'grupo': f.grupo,
            'data': f.data,
            'tipo': f.tipo,
            'valor': f.valor,
            'descricao': f.descricao,
            'criado_em': f.criadoEm.toIso8601String(),
          },
        )
        .toList();
    await _client.from('finances').upsert(rows);
    return rows.length;
  }

  Future<List<FinanceEntry>> _pullFinances() async {
    final data = await _client.from('finances').select();
    return (data as List)
        .map((e) => FinanceEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> _pushAttendance(AppState state) async {
    if (state.attendance.isEmpty) return 0;
    var peopleCount = 0;
    for (final s in state.attendance) {
      await _client.from('attendance_sessions').upsert({
        'id': s.id,
        'grupo': s.grupo,
        'data': s.data,
        'criado_em': s.criadoEm.toIso8601String(),
      });
      if (s.pessoas.isEmpty) continue;
      final people = s.pessoas
          .map(
            (p) => {
              'id': p.id,
              'session_id': s.id,
              'aluno_id': p.alunoId,
              'nome': p.nome,
              'presente': p.presente,
              'trouxe_biblia': p.trouxeBiblia,
            },
          )
          .toList();
      await _client.from('attendance_people').upsert(people);
      peopleCount += people.length;
    }
    return peopleCount;
  }

  Future<List<AttendanceSession>> _pullAttendance() async {
    final sessionsRaw = await _client.from('attendance_sessions').select();
    final peopleRaw = await _client.from('attendance_people').select();
    final bySession = <String, List<AttendancePerson>>{};
    for (final row in peopleRaw as List) {
      final m = Map<String, dynamic>.from(row as Map);
      final sid = m['session_id'] as String? ?? '';
      bySession
          .putIfAbsent(sid, () => [])
          .add(AttendancePerson.fromJson({
            ...m,
            'alunoId': m['aluno_id'],
            'trouxeBiblia': m['trouxe_biblia'],
          }));
    }
    return (sessionsRaw as List).map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      final id = m['id'] as String;
      return AttendanceSession(
        id: id,
        grupo: m['grupo'] as String,
        data: m['data'].toString().split('T').first,
        pessoas: bySession[id] ?? const [],
        criadoEm: DateTime.tryParse(m['criado_em']?.toString() ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  Future<void> _pushCustomGroups(AppState state) async {
    if (state.customGroups.isEmpty) return;
    final rows = state.customGroups
        .map((n) => {'nome': n, 'criado_em': DateTime.now().toIso8601String()})
        .toList();
    await _client.from('custom_groups').upsert(rows);
  }
}
