import 'package:livro_registro/data/user_models.dart';

/// Permissões granulares da plataforma EBD.
///
/// O acesso efetivo = preset do [UserRole] + overrides opcionais no usuário.
/// Admin tem sempre acesso total (ignora overrides negativos).
enum AppPermission {
  manageUsers,
  seeFinances,
  editAttendance,
  manageMagazines,
  seePanel,
  runSorteio,
  manageLessons,
  backup,
  seeAllClasses,
  manageGroups,
  syncBetel,
  seeReport,
  seeStudents,
  seeDesafios;

  String get label => switch (this) {
        AppPermission.manageUsers => 'Gerenciar usuários',
        AppPermission.seeFinances => 'Ver ofertas / finanças',
        AppPermission.editAttendance => 'Editar presença',
        AppPermission.manageMagazines => 'Gerenciar revistas',
        AppPermission.seePanel => 'Ver painel',
        AppPermission.runSorteio => 'Realizar sorteios',
        AppPermission.manageLessons => 'Gerenciar lições / Betel',
        AppPermission.backup => 'Backup e restauração',
        AppPermission.seeAllClasses => 'Ver todas as turmas',
        AppPermission.manageGroups => 'Criar / remover turmas',
        AppPermission.syncBetel => 'Sincronizar catálogo Betel',
        AppPermission.seeReport => 'Gerar relatório',
        AppPermission.seeStudents => 'Ver / editar alunos',
        AppPermission.seeDesafios => 'Sorteios, quiz e placar',
      };

  String get description => switch (this) {
        AppPermission.manageUsers =>
          'Cadastrar, editar e redefinir senhas de usuários.',
        AppPermission.seeFinances => 'Aba Ofertas e lançamentos financeiros.',
        AppPermission.editAttendance => 'Aba Presença e lançamento de faltas.',
        AppPermission.manageMagazines => 'Aba Revistas e entregas.',
        AppPermission.seePanel => 'Aba Painel com indicadores.',
        AppPermission.runSorteio => 'Executar sorteios (equipe).',
        AppPermission.manageLessons => 'Cadastro de lições e sync Betel.',
        AppPermission.backup => 'Exportar / restaurar dados do aparelho.',
        AppPermission.seeAllClasses => 'Navegar entre todas as classes.',
        AppPermission.manageGroups => 'Adicionar ou remover turmas extras.',
        AppPermission.syncBetel => 'Atualizar catálogo de revistas Betel.',
        AppPermission.seeReport => 'Botão Relatório / PDF geral.',
        AppPermission.seeStudents => 'Aba Alunos e cadastro por turma.',
        AppPermission.seeDesafios => 'Menu Sorteios, Quiz e Conquistas.',
      };
}

/// Presets de permissão por perfil (role).
Set<AppPermission> rolePermissionPreset(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return AppPermission.values.toSet();
    case UserRole.pastor:
      return {
        AppPermission.manageUsers,
        AppPermission.seeFinances,
        AppPermission.editAttendance,
        AppPermission.manageMagazines,
        AppPermission.seePanel,
        AppPermission.runSorteio,
        AppPermission.manageLessons,
        AppPermission.backup,
        AppPermission.seeAllClasses,
        AppPermission.manageGroups,
        AppPermission.seeReport,
        AppPermission.seeStudents,
        AppPermission.seeDesafios,
      };
    case UserRole.superintendente:
      return {
        AppPermission.manageUsers,
        AppPermission.seeFinances,
        AppPermission.editAttendance,
        AppPermission.manageMagazines,
        AppPermission.seePanel,
        AppPermission.runSorteio,
        AppPermission.manageLessons,
        AppPermission.backup,
        AppPermission.seeAllClasses,
        AppPermission.manageGroups,
        AppPermission.syncBetel,
        AppPermission.seeReport,
        AppPermission.seeStudents,
        AppPermission.seeDesafios,
      };
    case UserRole.professor:
      return {
        AppPermission.editAttendance,
        AppPermission.manageMagazines,
        AppPermission.runSorteio,
        AppPermission.seeReport,
        AppPermission.seeStudents,
        AppPermission.seeDesafios,
        AppPermission.backup,
      };
    case UserRole.aluno:
      // Sem editAttendance: não marca chamada da turma.
      // Aba Presença fica read-only / self-check-in na UI.
      return {
        AppPermission.seeDesafios,
      };
  }
}

/// Resolve se o usuário tem a permissão (preset + override; admin = sempre).
bool userHasPermission(UserProfile? user, AppPermission permission) {
  if (user == null) return false;
  if (user.role == UserRole.admin) return true;
  final overrides = user.permissionOverrides;
  if (overrides != null && overrides.containsKey(permission.name)) {
    return overrides[permission.name] == true;
  }
  return rolePermissionPreset(user.role).contains(permission);
}

extension UserProfilePermissions on UserProfile {
  bool can(AppPermission permission) => userHasPermission(this, permission);

  /// Mapa efetivo (útil para UI de checkboxes e backup).
  Map<String, bool> effectivePermissionMap() {
    final preset = rolePermissionPreset(role);
    final map = <String, bool>{
      for (final p in AppPermission.values) p.name: preset.contains(p),
    };
    if (role == UserRole.admin) {
      for (final p in AppPermission.values) {
        map[p.name] = true;
      }
      return map;
    }
    final overrides = permissionOverrides;
    if (overrides != null) {
      for (final e in overrides.entries) {
        map[e.key] = e.value;
      }
    }
    return map;
  }

  /// Diff em relação ao preset: só grava o que diverge.
  static Map<String, bool>? overridesFromEffective({
    required UserRole role,
    required Map<String, bool> effective,
  }) {
    if (role == UserRole.admin) return null;
    final preset = rolePermissionPreset(role);
    final out = <String, bool>{};
    for (final p in AppPermission.values) {
      final want = effective[p.name] ?? false;
      final base = preset.contains(p);
      if (want != base) out[p.name] = want;
    }
    return out.isEmpty ? null : out;
  }
}
