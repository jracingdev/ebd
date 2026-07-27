import 'package:equatable/equatable.dart';
import 'package:livro_registro/data/user_models.dart';

/// Classes/turmas padrão da EBD (sempre disponíveis; seed inicial).
const kGroups = <String>[
  'Maternal (2-3 anos)',
  'Pré-escolar (4-5 anos)',
  'Primários (6-8 anos)',
  'Juniores (9-11 anos)',
  'Adolescentes 12-14',
  'Adolescentes 15-17',
  'Jovens',
  'CIBE',
  'Varões',
];

bool isDefaultGroup(String grupo) => kGroups.contains(grupo);

/// Versão do formato de backup JSON.
const kBackupVersion = 7;

class Student extends Equatable {
  const Student({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.criadoEm,
    this.matricula,
    this.telefone,
    this.aniversario,
    this.fotoUrl,
  });

  final String id;
  final String nome;
  final String grupo;
  final DateTime criadoEm;
  final String? matricula;
  final String? telefone;
  final DateTime? aniversario;
  final String? fotoUrl;

  bool get isBirthdayToday {
    if (aniversario == null) return false;
    final now = DateTime.now();
    return aniversario!.day == now.day && aniversario!.month == now.month;
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? json['Id'] ?? json['_id'] ?? '').toString().trim();
    final nome = (json['nome'] ?? json['name'] ?? json['aluno'] ?? '')
        .toString()
        .trim();
    final grupo = (json['grupo'] ?? json['turma'] ?? json['classe'] ?? '')
        .toString()
        .trim();
    final criadoRaw = json['criadoEm'] ?? json['criado_em'] ?? json['createdAt'];
    final criadoEm = criadoRaw == null
        ? DateTime.now()
        : (DateTime.tryParse(criadoRaw.toString()) ?? DateTime.now());
    final id = rawId.isNotEmpty
        ? rawId
        : () {
            final gen =
                's${criadoEm.millisecondsSinceEpoch.toRadixString(36)}${nome.hashCode.abs().toRadixString(36)}';
            return gen.length > 12 ? gen.substring(0, 12) : gen;
          }();

    String? opt(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return Student(
      id: id,
      nome: nome.isEmpty ? 'Aluno' : nome,
      grupo: grupo.isEmpty ? kGroups.first : grupo,
      criadoEm: criadoEm,
      matricula: opt(json['matricula'] ?? json['matricula_id']),
      telefone: opt(json['telefone'] ?? json['phone'] ?? json['celular']),
      aniversario: json['aniversario'] == null && json['birthday'] == null
          ? null
          : DateTime.tryParse(
              (json['aniversario'] ?? json['birthday']).toString(),
            ),
      fotoUrl: opt(json['fotoUrl'] ?? json['foto_url'] ?? json['foto']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'grupo': grupo,
        'criadoEm': criadoEm.toIso8601String(),
        'matricula': matricula,
        'telefone': telefone,
        'aniversario': aniversario?.toIso8601String().split('T').first,
        'fotoUrl': fotoUrl,
      };

  Student copyWith({
    String? nome,
    String? grupo,
    String? matricula,
    String? telefone,
    DateTime? aniversario,
    String? fotoUrl,
    bool clearMatricula = false,
    bool clearTelefone = false,
    bool clearAniversario = false,
    bool clearFotoUrl = false,
  }) =>
      Student(
        id: id,
        nome: nome ?? this.nome,
        grupo: grupo ?? this.grupo,
        criadoEm: criadoEm,
        matricula: clearMatricula ? null : (matricula ?? this.matricula),
        telefone: clearTelefone ? null : (telefone ?? this.telefone),
        aniversario: clearAniversario ? null : (aniversario ?? this.aniversario),
        fotoUrl: clearFotoUrl ? null : (fotoUrl ?? this.fotoUrl),
      );

  @override
  List<Object?> get props =>
      [id, nome, grupo, criadoEm, matricula, telefone, aniversario, fotoUrl];
}

class Edition extends Equatable {
  const Edition({
    required this.id,
    required this.grupo,
    required this.trimestre,
    this.capa,
    this.tema,
    this.serie,
    this.sku,
    required this.criadoEm,
  });

  final String id;
  final String grupo;
  final String trimestre;
  final String? capa;
  final String? tema;
  final String? serie;
  final String? sku;
  final DateTime criadoEm;

  factory Edition.fromJson(Map<String, dynamic> json) => Edition(
        id: json['id'] as String,
        grupo: json['grupo'] as String,
        trimestre: json['trimestre'] as String,
        capa: json['capa'] as String?,
        tema: json['tema'] as String?,
        serie: json['serie'] as String?,
        sku: json['sku'] as String?,
        criadoEm: DateTime.parse(
          (json['criadoEm'] ?? json['criado_em']).toString(),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'grupo': grupo,
        'trimestre': trimestre,
        'capa': capa,
        'tema': tema,
        'serie': serie,
        'sku': sku,
        'criadoEm': criadoEm.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, grupo, trimestre, capa, tema, serie, sku, criadoEm];
}

class DeliveryRecord extends Equatable {
  const DeliveryRecord({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.edicaoId,
    required this.valor,
    required this.status,
    required this.data,
  });

  final String id;
  final String nome;
  final String grupo;
  final String edicaoId;
  final double valor;
  final String status;
  final DateTime data;

  bool get isPago => status == 'pago';

  factory DeliveryRecord.fromJson(Map<String, dynamic> json) => DeliveryRecord(
        id: json['id'] as String,
        nome: json['nome'] as String,
        grupo: json['grupo'] as String,
        edicaoId: json['edicaoId'] as String? ?? json['edicao_id'] as String,
        valor: (json['valor'] as num).toDouble(),
        status: json['status'] as String,
        data: DateTime.parse(json['data'].toString()),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'grupo': grupo,
        'edicaoId': edicaoId,
        'valor': valor,
        'status': status,
        'data': data.toIso8601String(),
      };

  DeliveryRecord copyWith({String? status}) => DeliveryRecord(
        id: id,
        nome: nome,
        grupo: grupo,
        edicaoId: edicaoId,
        valor: valor,
        status: status ?? this.status,
        data: data,
      );

  @override
  List<Object?> get props => [id, nome, grupo, edicaoId, valor, status, data];
}

class FinanceEntry extends Equatable {
  const FinanceEntry({
    required this.id,
    required this.grupo,
    required this.data,
    required this.tipo,
    required this.valor,
    required this.descricao,
    required this.criadoEm,
  });

  final String id;
  final String grupo;
  final String data;
  final String tipo;
  final double valor;
  final String descricao;
  final DateTime criadoEm;

  factory FinanceEntry.fromJson(Map<String, dynamic> json) => FinanceEntry(
        id: json['id'] as String,
        grupo: json['grupo'] as String,
        data: json['data'] as String,
        tipo: json['tipo'] as String,
        valor: (json['valor'] as num).toDouble(),
        descricao: (json['descricao'] as String?) ?? '',
        criadoEm: DateTime.parse(
          (json['criadoEm'] ?? json['criado_em']).toString(),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'grupo': grupo,
        'data': data,
        'tipo': tipo,
        'valor': valor,
        'descricao': descricao,
        'criadoEm': criadoEm.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, grupo, data, tipo, valor, descricao, criadoEm];
}

class AttendancePerson extends Equatable {
  const AttendancePerson({
    required this.id,
    required this.nome,
    required this.presente,
    this.alunoId,
    this.trouxeBiblia = false,
  });

  final String id;
  final String nome;
  final bool presente;
  final String? alunoId;

  /// Marca se o aluno trouxe a Bíblia na sessão.
  final bool trouxeBiblia;

  factory AttendancePerson.fromJson(Map<String, dynamic> json) =>
      AttendancePerson(
        id: json['id'] as String,
        nome: json['nome'] as String,
        presente: json['presente'] as bool? ?? false,
        alunoId: json['alunoId'] as String? ?? json['aluno_id'] as String?,
        trouxeBiblia: json['trouxeBiblia'] as bool? ??
            json['trouxe_biblia'] as bool? ??
            false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'presente': presente,
        if (alunoId != null) 'alunoId': alunoId,
        'trouxeBiblia': trouxeBiblia,
      };

  AttendancePerson copyWith({bool? presente, bool? trouxeBiblia}) =>
      AttendancePerson(
        id: id,
        nome: nome,
        presente: presente ?? this.presente,
        alunoId: alunoId,
        trouxeBiblia: trouxeBiblia ?? this.trouxeBiblia,
      );

  @override
  List<Object?> get props => [id, nome, presente, alunoId, trouxeBiblia];
}

class AttendanceSession extends Equatable {
  const AttendanceSession({
    required this.id,
    required this.grupo,
    required this.data,
    required this.pessoas,
    required this.criadoEm,
  });

  final String id;
  final String grupo;
  final String data;
  final List<AttendancePerson> pessoas;
  final DateTime criadoEm;

  int get presentes => pessoas.where((p) => p.presente).length;
  int get ausentes => pessoas.where((p) => !p.presente).length;

  factory AttendanceSession.fromJson(Map<String, dynamic> json) =>
      AttendanceSession(
        id: json['id'] as String,
        grupo: json['grupo'] as String,
        data: json['data'] as String,
        pessoas: (json['pessoas'] as List<dynamic>? ?? [])
            .map((e) => AttendancePerson.fromJson(e as Map<String, dynamic>))
            .toList(),
        criadoEm: DateTime.parse(
          (json['criadoEm'] ?? json['criado_em']).toString(),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'grupo': grupo,
        'data': data,
        'pessoas': pessoas.map((e) => e.toJson()).toList(),
        'criadoEm': criadoEm.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, grupo, data, pessoas, criadoEm];
}

class AppBackup extends Equatable {
  const AppBackup({
    required this.version,
    required this.exportedAt,
    required this.editions,
    required this.records,
    required this.finances,
    required this.attendance,
    required this.students,
    this.lessons = const [],
    this.customGroups = const [],
    this.engagement = const {},
    this.users = const [],
  });

  final int version;
  final DateTime exportedAt;
  final List<Edition> editions;
  final List<DeliveryRecord> records;
  final List<FinanceEntry> finances;
  final List<AttendanceSession> attendance;
  final List<Student> students;
  final List<Lesson> lessons;
  final List<String> customGroups;

  /// Dados de sorteios / quiz / placar (mapa serializado).
  final Map<String, dynamic> engagement;

  /// Usuários locais (perfis + overrides; senhas opcionais).
  final List<Map<String, dynamic>> users;

  factory AppBackup.fromJson(Map<String, dynamic> json) => AppBackup(
        version: json['version'] as int? ?? kBackupVersion,
        exportedAt: DateTime.parse(json['exportedAt'] as String),
        editions: (json['editions'] as List<dynamic>? ?? [])
            .map((e) => Edition.fromJson(e as Map<String, dynamic>))
            .toList(),
        records: (json['records'] as List<dynamic>? ?? [])
            .map((e) => DeliveryRecord.fromJson(e as Map<String, dynamic>))
            .toList(),
        finances: (json['finances'] as List<dynamic>? ?? [])
            .map((e) => FinanceEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        attendance: (json['attendance'] as List<dynamic>? ?? [])
            .map((e) => AttendanceSession.fromJson(e as Map<String, dynamic>))
            .toList(),
        students: (json['students'] as List<dynamic>? ?? [])
            .map((e) => Student.fromJson(e as Map<String, dynamic>))
            .toList(),
        lessons: (json['lessons'] as List<dynamic>? ?? [])
            .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
            .toList(),
        customGroups: (json['customGroups'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .where((g) => g.trim().isNotEmpty && !isDefaultGroup(g))
            .toList(),
        engagement: json['engagement'] is Map
            ? Map<String, dynamic>.from(json['engagement'] as Map)
            : const {},
        users: (json['users'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'editions': editions.map((e) => e.toJson()).toList(),
        'records': records.map((e) => e.toJson()).toList(),
        'finances': finances.map((e) => e.toJson()).toList(),
        'attendance': attendance.map((e) => e.toJson()).toList(),
        'students': students.map((e) => e.toJson()).toList(),
        'lessons': lessons.map((e) => e.toJson()).toList(),
        'customGroups': customGroups,
        'engagement': engagement,
        'users': users,
      };

  @override
  List<Object?> get props => [
        version,
        exportedAt,
        editions,
        records,
        finances,
        attendance,
        students,
        lessons,
        customGroups,
        engagement,
        users,
      ];
}

class EditionTotals {
  const EditionTotals({
    required this.pago,
    required this.pendente,
    required this.count,
    required this.items,
  });

  final double pago;
  final double pendente;
  final int count;
  final List<DeliveryRecord> items;

  int get countPago => items.where((e) => e.isPago).length;
  int get countPendente => items.where((e) => !e.isPago).length;
}

EditionTotals editionTotalsOf(List<DeliveryRecord> records, String edId) {
  final items = records.where((r) => r.edicaoId == edId).toList();
  final pago =
      items.where((r) => r.isPago).fold<double>(0, (s, r) => s + r.valor);
  final pendente =
      items.where((r) => !r.isPago).fold<double>(0, (s, r) => s + r.valor);
  return EditionTotals(
      pago: pago, pendente: pendente, count: items.length, items: items);
}
