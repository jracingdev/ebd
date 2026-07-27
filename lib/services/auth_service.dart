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
      aniversario: DateTime(1990, DateTime.now().month, DateTime.now().day),
    );
    await _localUsers!.put(admin.matricula, {
      ...admin.toJson(),
      'senha': 'admin123',
    });
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
    final profile = UserProfile.fromJson(map);
    if (!profile.ativo) throw AuthException('Usuário inativo.');
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
  }) async {
    final mat = matricula.trim();
    if (usingSupabase) {
      final signed = await Supabase.instance.client.auth.signUp(
        email: email?.isNotEmpty == true
            ? email!
            : AppConfig.matriculaToEmail(mat),
        password: senha,
        data: {
          'matricula': mat,
          'nome': nome,
          'role': role.name,
          'grupo': grupo,
        },
      );
      if (signed.user == null) {
        throw AuthException('Não foi possível criar o usuário.');
      }
      await Supabase.instance.client.from('profiles').upsert({
        'id': signed.user!.id,
        'matricula': mat,
        'nome': nome,
        'role': role.name,
        'grupo': grupo,
        'telefone': telefone,
        'email': email,
        'aniversario': aniversario?.toIso8601String().split('T').first,
      });
      return UserProfile(
        id: signed.user!.id,
        matricula: mat,
        nome: nome,
        role: role,
        grupo: grupo,
        telefone: telefone,
        email: email,
        aniversario: aniversario,
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

  Future<List<UserProfile>> listLocalUsers() async {
    return _localUsers!.values
        .whereType<Map>()
        .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String?> lastMatricula() => _secure.read(key: 'last_matricula');
  Future<String?> lastSenha() => _secure.read(key: 'last_senha');

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
