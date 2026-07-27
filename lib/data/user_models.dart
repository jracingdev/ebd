/// Roles de acesso da plataforma EBD.
enum UserRole {
  aluno,
  professor,
  superintendente,
  pastor,
  admin;

  String get label => switch (this) {
        UserRole.aluno => 'Aluno',
        UserRole.professor => 'Professor',
        UserRole.superintendente => 'Superintendente',
        UserRole.pastor => 'Pastor',
        UserRole.admin => 'Admin',
      };

  bool get isStaff => this != UserRole.aluno;

  bool get seesAllClasses =>
      this == UserRole.superintendente ||
      this == UserRole.pastor ||
      this == UserRole.admin;

  bool get canManageUsers =>
      this == UserRole.admin ||
      this == UserRole.pastor ||
      this == UserRole.superintendente;

  /// Admin, pastor e superintendente podem criar/excluir turmas extras.
  bool get canManageGroups => seesAllClasses;

  bool get canSyncBetel =>
      this == UserRole.admin || this == UserRole.superintendente;

  static UserRole fromString(String? value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.aluno,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.matricula,
    required this.nome,
    required this.role,
    this.grupo,
    this.telefone,
    this.email,
    this.aniversario,
    this.fotoUrl,
    this.ativo = true,
  });

  final String id;
  final String matricula;
  final String nome;
  final UserRole role;
  final String? grupo;
  final String? telefone;
  final String? email;
  final DateTime? aniversario;
  final String? fotoUrl;
  final bool ativo;

  bool get isBirthdayToday {
    if (aniversario == null) return false;
    final now = DateTime.now();
    return aniversario!.day == now.day && aniversario!.month == now.month;
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        matricula: json['matricula'] as String,
        nome: json['nome'] as String,
        role: UserRole.fromString(json['role'] as String?),
        grupo: json['grupo'] as String?,
        telefone: json['telefone'] as String?,
        email: json['email'] as String?,
        aniversario: json['aniversario'] == null
            ? null
            : DateTime.tryParse(json['aniversario'].toString()),
        fotoUrl: json['foto_url'] as String? ?? json['fotoUrl'] as String?,
        ativo: json['ativo'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'matricula': matricula,
        'nome': nome,
        'role': role.name,
        'grupo': grupo,
        'telefone': telefone,
        'email': email,
        'aniversario': aniversario?.toIso8601String().split('T').first,
        'foto_url': fotoUrl,
        'ativo': ativo,
      };

  UserProfile copyWith({
    String? nome,
    String? grupo,
    String? telefone,
    String? email,
    DateTime? aniversario,
    String? fotoUrl,
  }) =>
      UserProfile(
        id: id,
        matricula: matricula,
        nome: nome ?? this.nome,
        role: role,
        grupo: grupo ?? this.grupo,
        telefone: telefone ?? this.telefone,
        email: email ?? this.email,
        aniversario: aniversario ?? this.aniversario,
        fotoUrl: fotoUrl ?? this.fotoUrl,
        ativo: ativo,
      );
}

class Lesson {
  const Lesson({
    required this.id,
    required this.editionId,
    required this.numero,
    required this.titulo,
    required this.dataDomingo,
    this.grupo,
  });

  final String id;
  final String editionId;
  final int numero;
  final String titulo;
  final DateTime dataDomingo;
  final String? grupo;

  factory Lesson.fromJson(Map<String, dynamic> json) => Lesson(
        id: json['id'] as String,
        editionId: json['edition_id'] as String? ?? json['editionId'] as String,
        numero: json['numero'] as int,
        titulo: json['titulo'] as String,
        dataDomingo: DateTime.parse(
          (json['data_domingo'] ?? json['dataDomingo']).toString(),
        ),
        grupo: json['grupo'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'edition_id': editionId,
        'editionId': editionId,
        'numero': numero,
        'titulo': titulo,
        'data_domingo': dataDomingo.toIso8601String().split('T').first,
        'dataDomingo': dataDomingo.toIso8601String().split('T').first,
        'grupo': grupo,
      };
}

class BetelCatalogItem {
  const BetelCatalogItem({
    required this.grupo,
    required this.trimestre,
    required this.serie,
    this.tema,
    this.sku,
    this.capaUrl,
    this.produtoUrl,
    this.preco,
  });

  final String grupo;
  final String trimestre;
  final String serie;
  final String? tema;
  final String? sku;
  final String? capaUrl;
  final String? produtoUrl;
  final double? preco;

  Map<String, dynamic> toJson() => {
        'grupo': grupo,
        'trimestre': trimestre,
        'serie': serie,
        'tema': tema,
        'sku': sku,
        'capa_url': capaUrl,
        'produto_url': produtoUrl,
        'preco': preco,
      };
}
