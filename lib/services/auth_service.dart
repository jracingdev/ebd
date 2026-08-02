import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:livro_registro/config/app_config.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Auth com Supabase quando configurado; senão, modo local (Hive) para desenvolvimento.
class AuthService extends ChangeNotifier {
  AuthService();

  final _secure = const FlutterSecureStorage();
  final _uuid = const Uuid();
  Box? _localUsers;
  Box? _session;

  UserProfile? currentUser;
  bool ready = false;
  bool get isLoggedIn => currentUser != null;
  bool get usingSupabase => AppConfig.supabaseConfigured;

  Future<void> init() async {
    _localUsers = await Hive.openBox('ebd_users_v1');
    _session = await Hive.openBox('ebd_session_v1');
    await _seedLocalAdminIfNeeded();
    await _clearDemoAdminFakeBirthday();

    if (usingSupabase) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        publishableKey: AppConfig.supabaseAnonKey,
      );
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        currentUser = await _fetchProfile(session.user.id);
      }
    } else {
      final raw = _session!.get('user');
      if (raw is String) {
        currentUser = UserProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        currentUser = await _sanitizeLoadedUser(currentUser);
      }
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _seedLocalAdminIfNeeded() async {
    if (_localUsers!.isNotEmpty) return;
    final admin = UserProfile(
      id: _uuid.v4(),
      matricula: 'admin',
      nome: 'Administrador',
      role: UserRole.admin,
      email: 'admin@ebd.local',
    );
    await _localUsers!.put(admin.matricula, {
      ...admin.toJson(),
      'senha': 'admin123',
    });
  }

  /// Seed antigo usava ano 1990 + dia de hoje → overlay de aniversário todo dia.
  Future<void> _clearDemoAdminFakeBirthday() async {
    final raw = _localUsers!.get('admin');
    if (raw is! Map) return;
    final map = Map<String, dynamic>.from(raw);
    if (!_isDemoFakeBirthday(map['aniversario'])) return;
    map['aniversario'] = null;
    await _localUsers!.put('admin', map);
  }

  bool _isDemoFakeBirthday(Object? raw) {
    if (raw == null) return false;
    if (raw is DateTime) return raw.year == 1990;
    final s = raw.toString();
    final parsed = DateTime.tryParse(s.split(' ').first);
    return parsed != null && parsed.year == 1990;
  }

  Future<UserProfile?> _sanitizeLoadedUser(UserProfile? user) async {
    if (user == null) return null;
    final a = user.aniversario;
    if (user.matricula != 'admin' || a == null || a.year != 1990) {
      return user;
    }
    final fixed = user.copyWith(clearAniversario: true);
    final hiveRaw = _localUsers!.get('admin');
    if (hiveRaw is Map) {
      final map = Map<String, dynamic>.from(hiveRaw);
      map['aniversario'] = null;
      await _localUsers!.put('admin', map);
    }
    await _session!.put('user', jsonEncode(fixed.toJson()));
    return fixed;
  }

  Future<UserProfile?> _fetchProfile(String id) async {
    final row = await Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return UserProfile.fromJson(Map<String, dynamic>.from(row));
  }

  Future<UserProfile> login({
    required String matricula,
    required String senha,
  }) async {
    final mat = matricula.trim();
    if (mat.isEmpty || senha.isEmpty) {
      throw AuthException('Informe matrícula e senha.');
    }

    if (usingSupabase) {
      final email = AppConfig.matriculaToEmail(mat);
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: senha,
      );
      final user = res.user;
      if (user == null) throw AuthException('Falha no login.');
      final profile = await _fetchProfile(user.id);
      if (profile == null || !profile.ativo) {
        throw AuthException('Perfil não encontrado ou inativo.');
      }
      currentUser = profile;
      await _secure.write(key: 'last_matricula', value: mat);
      await _secure.write(key: 'last_senha', value: senha);
      notifyListeners();
      return profile;
    }

    final raw = _localUsers!.get(mat);
    if (raw is! Map) throw AuthException('Matrícula não encontrada.');
    final map = Map<String, dynamic>.from(raw);
    if (map['senha'] != senha) throw AuthException('Senha incorreta.');
    var profile = UserProfile.fromJson(map);
    if (!profile.ativo) throw AuthException('Usuário inativo.');
    profile = await _sanitizeLoadedUser(profile) ?? profile;
    currentUser = profile;
    await _session!.put('user', jsonEncode(profile.toJson()));
    await _secure.write(key: 'last_matricula', value: mat);
    await _secure.write(key: 'last_senha', value: senha);
    notifyListeners();
    return profile;
  }

  Future<void> logout({bool clearBiometric = false}) async {
    if (usingSupabase) {
      await Supabase.instance.client.auth.signOut();
    }
    await _session?.delete('user');
    currentUser = null;
    if (clearBiometric) {
      await _secure.delete(key: 'biometric_enabled');
      await _secure.delete(key: 'last_matricula');
      await _secure.delete(key: 'last_senha');
    }
    notifyListeners();
  }

  Future<void> requestPasswordReset(String matricula) async {
    final mat = matricula.trim();
    if (mat.isEmpty) throw AuthException('Informe a matrícula.');

    if (usingSupabase) {
      // Resolve e-mail real do profile, se houver; senão usa sintético.
      final row = await Supabase.instance.client
          .from('profiles')
          .select('email, matricula')
          .eq('matricula', mat)
          .maybeSingle();
      if (row == null) {
        throw AuthException('Matrícula não encontrada.');
      }
      final email = (row['email'] as String?)?.isNotEmpty == true
          ? row['email'] as String
          : AppConfig.matriculaToEmail(mat);
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      return;
    }

    final raw = _localUsers!.get(mat);
    if (raw is! Map) throw AuthException('Matrícula não encontrada.');
    // Modo local: redefine para senha temporária conhecida.
    final map = Map<String, dynamic>.from(raw);
    map['senha'] = 'ebd${mat.substring(0, mat.length.clamp(0, 4))}';
    await _localUsers!.put(mat, map);
  }

  Future<UserProfile> createUser({
    required String matricula,
    required String nome,
    required String senha,
    required UserRole role,
    String? grupo,
    String? telefone,
    String? email,
    DateTime? aniversario,
    bool ativo = true,
    Map<String, bool>? permissionOverrides,
  }) async {
    final mat = matricula.trim();
    if (usingSupabase) {
      // signUp no client troca a sessão do admin pelo novo usuário.
      // Cadastro cloud: Dashboard Auth / API Admin (service role), ver SETUP_CLOUD.md.
      throw AuthException(
        'Com Supabase ativo, crie usuários pelo Dashboard (Auth → Add user + '
        'promover em profiles). O cadastro pelo app encerraria a sessão do admin.',
      );
    }

    if (_localUsers!.containsKey(mat)) {
      throw AuthException('Matrícula já cadastrada.');
    }
    final profile = UserProfile(
      id: _uuid.v4(),
      matricula: mat,
      nome: nome,
      role: role,
      grupo: grupo,
      telefone: telefone,
      email: email,
      aniversario: aniversario,
      ativo: ativo,
      permissionOverrides: permissionOverrides,
    );
    await _localUsers!.put(mat, {...profile.toJson(), 'senha': senha});
    return profile;
  }

  Future<void> resetUserPassword(String matricula, String novaSenha) async {
    if (usingSupabase) {
      throw AuthException(
        'No Supabase, use o painel Admin ou o e-mail de recuperação.',
      );
    }
    final raw = _localUsers!.get(matricula.trim());
    if (raw is! Map) throw AuthException('Matrícula não encontrada.');
    final map = Map<String, dynamic>.from(raw);
    map['senha'] = novaSenha;
    await _localUsers!.put(matricula.trim(), map);
  }

  int get activeAdminCount {
    return localUsersSnapshot
        .where((u) => u.ativo && u.role == UserRole.admin)
        .length;
  }

  /// Impede remover/desativar/rebaixar o último admin ativo.
  void _ensureNotLastAdmin({
    required UserProfile before,
    required UserProfile after,
  }) {
    final wasAdmin = before.ativo && before.role == UserRole.admin;
    final stillAdmin = after.ativo && after.role == UserRole.admin;
    if (wasAdmin && !stillAdmin && activeAdminCount <= 1) {
      throw AuthException(
        'Não é possível remover ou desativar o último administrador.',
      );
    }
  }

  Future<UserProfile> updateUser({
    required String matricula,
    String? nome,
    UserRole? role,
    String? grupo,
    bool clearGrupo = false,
    String? telefone,
    String? email,
    DateTime? aniversario,
    bool clearAniversario = false,
    bool? ativo,
    Map<String, bool>? permissionOverrides,
    bool clearPermissionOverrides = false,
    String? novaSenha,
  }) async {
    if (usingSupabase) {
      throw AuthException(
        'Edição completa de perfil no Supabase ainda não está disponível neste app.',
      );
    }
    final mat = matricula.trim();
    final raw = _localUsers!.get(mat);
    if (raw is! Map) throw AuthException('Matrícula não encontrada.');
    final map = Map<String, dynamic>.from(raw);
    final before = UserProfile.fromJson(map);
    var after = before.copyWith(
      nome: nome,
      role: role,
      grupo: grupo,
      clearGrupo: clearGrupo,
      telefone: telefone,
      email: email,
      aniversario: aniversario,
      clearAniversario: clearAniversario,
      ativo: ativo,
      permissionOverrides: permissionOverrides,
      clearPermissionOverrides: clearPermissionOverrides,
    );
    _ensureNotLastAdmin(before: before, after: after);
    final senha = map['senha'];
    final saved = {...after.toJson(), if (senha != null) 'senha': senha};
    if (novaSenha != null && novaSenha.trim().isNotEmpty) {
      saved['senha'] = novaSenha.trim();
    }
    await _localUsers!.put(mat, saved);

    if (currentUser?.matricula == mat) {
      currentUser = after;
      await _session!.put('user', jsonEncode(after.toJson()));
      notifyListeners();
    }
    return after;
  }

  /// Exporta usuários locais (sem senhas) para backup.
  List<Map<String, dynamic>> exportUsersForBackup({bool includePasswords = false}) {
    if (_localUsers == null) return const [];
    final out = <Map<String, dynamic>>[];
    for (final raw in _localUsers!.values) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      if (!includePasswords) map.remove('senha');
      out.add(map);
    }
    return out;
  }

  /// Restaura usuários de um backup (preserva senhas existentes se o backup não tiver).
  Future<void> importUsersFromBackup(List<dynamic> users) async {
    if (usingSupabase || _localUsers == null) return;
    for (final item in users) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final mat = (map['matricula'] as String?)?.trim();
      if (mat == null || mat.isEmpty) continue;
      final existing = _localUsers!.get(mat);
      if (map['senha'] == null && existing is Map && existing['senha'] != null) {
        map['senha'] = existing['senha'];
      }
      map['senha'] ??= 'ebd$mat';
      // Valida estrutura mínima.
      UserProfile.fromJson(map);
      await _localUsers!.put(mat, map);
    }
    notifyListeners();
  }

  Future<List<UserProfile>> listLocalUsers() async {
    return localUsersSnapshot;
  }

  /// Snapshot síncrono dos usuários locais (Hive).
  List<UserProfile> get localUsersSnapshot {
    if (_localUsers == null) return const [];
    return _localUsers!.values
        .whereType<Map>()
        .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
  }

  Future<String?> lastMatricula() => _secure.read(key: 'last_matricula');
  Future<String?> lastSenha() => _secure.read(key: 'last_senha');

  /// Prefill de matrícula na tela de login (não guarda senha).
  Future<bool> isRememberMeEnabled() async {
    return (await _secure.read(key: 'remember_me')) == '1';
  }

  Future<String?> rememberedMatricula() async {
    if (!await isRememberMeEnabled()) return null;
    return _secure.read(key: 'remembered_matricula');
  }

  Future<void> persistRememberMe({
    required bool remember,
    required String matricula,
  }) async {
    final mat = matricula.trim();
    if (remember && mat.isNotEmpty) {
      await _secure.write(key: 'remember_me', value: '1');
      await _secure.write(key: 'remembered_matricula', value: mat);
    } else {
      await _secure.delete(key: 'remember_me');
      await _secure.delete(key: 'remembered_matricula');
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secure.write(
      key: 'biometric_enabled',
      value: enabled ? '1' : '0',
    );
  }

  Future<bool> isBiometricEnabled() async {
    return (await _secure.read(key: 'biometric_enabled')) == '1';
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
