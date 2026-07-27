import 'package:equatable/equatable.dart';

/// Grupos/turmas da EBD (espelha o protótipo JSX e o app Flutter instalado).
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

/// Versão do formato de backup JSON (`ebd-backup.json`).
const kBackupVersion = 3;

class Student extends Equatable {
  const Student({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.criadoEm,
  });

  final String id;
  final String nome;
  final String grupo;
  final DateTime criadoEm;

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        nome: json['nome'] as String,
        grupo: json['grupo'] as String,
        criadoEm: DateTime.parse(json['criadoEm'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'grupo': grupo,
        'criadoEm': criadoEm.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, nome, grupo, criadoEm];
}

class Edition extends Equatable {
  const Edition({
    required this.id,
    required this.grupo,
    required this.trimestre,
    this.capa,
    required this.criadoEm,
  });

  final String id;
  final String grupo;
  final String trimestre;
  final String? capa; // data URL ou path
  final DateTime criadoEm;

  factory Edition.fromJson(Map<String, dynamic> json) => Edition(
        id: json['id'] as String,
        grupo: json['grupo'] as String,
        trimestre: json['trimestre'] as String,
        capa: json['capa'] as String?,
        criadoEm: DateTime.parse(json['criadoEm'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'grupo': grupo,
        'trimestre': trimestre,
        'capa': capa,
        'criadoEm': criadoEm.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, grupo, trimestre, capa, criadoEm];
}

/// Entrega/pagamento de revista (DeliveryRecord no binário).
class DeliveryRecord extends Equatable {
  const DeliveryRecord({
    required this.id,
    required this.nome,
    required this.grupo,
    required this.edicaoId,
    required this.valor,
    required this.status, // pago | pendente
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
        edicaoId: json['edicaoId'] as String,
        valor: (json['valor'] as num).toDouble(),
        status: json['status'] as String,
        data: DateTime.parse(json['data'] as String),
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
    required this.data, // yyyy-MM-dd
    required this.tipo, // oferta | doacao
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
        criadoEm: DateTime.parse(json['criadoEm'] as String),
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
  List<Object?> get props => [id, grupo, data, tipo, valor, descricao, criadoEm];
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
        alunoId: json['alunoId'] as String?,
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
    required this.data, // yyyy-MM-dd
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
        pessoas: (json['pessoas'] as List<dynamic>)
            .map((e) => AttendancePerson.fromJson(e as Map<String, dynamic>))
            .toList(),
        criadoEm: DateTime.parse(json['criadoEm'] as String),
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
  });

  final int version;
  final DateTime exportedAt;
  final List<Edition> editions;
  final List<DeliveryRecord> records;
  final List<FinanceEntry> finances;
  final List<AttendanceSession> attendance;
  final List<Student> students;

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
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'editions': editions.map((e) => e.toJson()).toList(),
        'records': records.map((e) => e.toJson()).toList(),
        'finances': finances.map((e) => e.toJson()).toList(),
        'attendance': attendance.map((e) => e.toJson()).toList(),
        'students': students.map((e) => e.toJson()).toList(),
      };

  @override
  List<Object?> get props =>
      [version, exportedAt, editions, records, finances, attendance, students];
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
