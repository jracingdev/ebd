import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/auth_service.dart';

class BiometricService {
  BiometricService(this._auth);

  final AuthService _auth;
  final _localAuth = LocalAuthentication();

  Future<bool> get isSupported async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return false;
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate({String reason = 'Desbloqueie o EBD'}) async {
    if (!await isSupported) return false;
    try {
      return await _localAuth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }

  Future<UserProfile?> tryBiometricLogin() async {
    if (!await _auth.isBiometricEnabled()) return null;
    if (!await isSupported) return null;
    final ok = await authenticate();
    if (!ok) return null;
    final mat = await _auth.lastMatricula();
    final senha = await _auth.lastSenha();
    if (mat == null || senha == null) return null;
    return _auth.login(matricula: mat, senha: senha);
  }
}
