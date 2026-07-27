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
const kBackupVersion = 5;

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

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        nome: json['nome'] as String,
        grupo: json['grupo'] as String,
        criadoEm: DateTime.parse(
          (json['criadoEm'] ?? json['criado_em']).toString(),
        ),
        matricula: json['matricula'] as String?,
        telefone: json['telefone'] as String?,
        aniversario: json['aniversario'] == null
            ? null
            : DateTime.tryParse(json['aniversario'].toString()),
        fotoUrl: json['fotoUrl'] as String? ?? json['foto_url'] as String?,
      );

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
  }) =>
      Student(
        id: id,
        nome: nome ?? this.nome,
        grupo: grupo ?? this.grupo,
        criadoEm: criadoEm,
        matricula: matricula ?? this.matricula,
        telefone: telefone ?? this.telefone,
        aniversario: aniversario ?? this.aniversario,
        fotoUrl: fotoUrl ?? this.fotoUrl,
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
  });

  final String id;
  final String nome;
  final bool presente;
  final String? alunoId;

  factory AttendancePerson.fromJson(Map<String, dynamic> json) =>
      AttendancePerson(
        id: json['id'] as String,
        nome: json['nome'] as String,
        presente: json['presente'] as bool? ?? false,
        alunoId: json['alunoId'] as String? ?? json['aluno_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'presente': presente,
        if (alunoId != null) 'alunoId': alunoId,
      };

  AttendancePerson copyWith({bool? presente}) => AttendancePerson(
        id: id,
        nome: nome,
        presente: presente ?? this.presente,
        alunoId: alunoId,
      );

  @override
  List<Object?> get props => [id, nome, presente, alunoId];
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
