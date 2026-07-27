import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/auth_service.dart';

class BiometricException implements Exception {
  BiometricException(this.message, {this.canceled = false});
  final String message;
  final bool canceled;
  @override
  String toString() => message;
}

class BiometricService {
  BiometricService(this._auth);

  final AuthService _auth;
  final _localAuth = LocalAuthentication();

  /// Hardware/OS suportam biometria (ou credencial do dispositivo).
  Future<bool> get isSupported async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) return false;
      final deviceOk = await _localAuth.isDeviceSupported();
      if (!deviceOk) return false;
      final canCheck = await _localAuth.canCheckBiometrics;
      if (canCheck) return true;
      final types = await _localAuth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (e, st) {
      debugPrint('[BiometricService] isSupported falhou: $e\n$st');
      return false;
    }
  }

  /// Solicita biometria. Retorna `true` se ok.
  /// Em cancelamento/falha lança [BiometricException] (com `canceled` quando aplicável).
  Future<bool> authenticate({
    String reason = 'Desbloqueie o EBD',
  }) async {
    if (!await isSupported) {
      throw BiometricException(
        'Biometria não disponível neste aparelho. Cadastre digital/Face nas configurações.',
      );
    }
    try {
      final ok = await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (!ok) {
        throw BiometricException(
          'Autenticação biométrica não confirmada.',
          canceled: true,
        );
      }
      return true;
    } on LocalAuthException catch (e, st) {
      debugPrint(
        '[BiometricService] LocalAuthException: ${e.code.name} ${e.description}\n$st',
      );
      throw BiometricException(
        _mapLocalAuthError(e),
        canceled: e.code == LocalAuthExceptionCode.userCanceled ||
            e.code == LocalAuthExceptionCode.systemCanceled,
      );
    } catch (e, st) {
      if (e is BiometricException) rethrow;
      debugPrint('[BiometricService] authenticate erro: $e\n$st');
      throw BiometricException('Não foi possível usar a biometria: $e');
    }
  }

  String _mapLocalAuthError(LocalAuthException e) {
    switch (e.code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
        return 'Autenticação biométrica cancelada.';
      case LocalAuthExceptionCode.timeout:
        return 'Tempo esgotado na biometria. Tente de novo.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Nenhuma biometria cadastrada. Configure digital ou Face no aparelho.';
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Este aparelho não tem hardware de biometria.';
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'Biometria temporariamente indisponível. Tente novamente.';
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Biometria temporariamente bloqueada. Tente novamente em instantes.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'Biometria bloqueada. Desbloqueie o aparelho com PIN/senha.';
      case LocalAuthExceptionCode.uiUnavailable:
        return e.description?.contains('FragmentActivity') == true
            ? 'Erro de configuração Android (Activity). Reinstale o app atualizado.'
            : 'Não foi possível exibir a biometria agora. Tente de novo.';
      case LocalAuthExceptionCode.userRequestedFallback:
        return 'Use matrícula e senha para entrar.';
      case LocalAuthExceptionCode.authInProgress:
        return 'Já há uma autenticação em andamento.';
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return e.description?.isNotEmpty == true
            ? e.description!
            : 'Falha na biometria.';
    }
  }

  /// Ativa biometria após confirmar a digital/Face (credenciais já no secure storage).
  Future<void> enableAfterLogin() async {
    final mat = await _auth.lastMatricula();
    final senha = await _auth.lastSenha();
    if (mat == null || senha == null) {
      throw BiometricException(
        'Não foi possível salvar credenciais para biometria. Faça login novamente.',
      );
    }
    await authenticate(
      reason: 'Confirme para ativar o desbloqueio biométrico do EBD',
    );
    await _auth.setBiometricEnabled(true);
  }

  Future<UserProfile?> tryBiometricLogin() async {
    if (!await _auth.isBiometricEnabled()) {
      throw BiometricException(
        'Biometria ainda não foi ativada neste aparelho.',
      );
    }
    if (!await isSupported) {
      throw BiometricException('Biometria não disponível neste aparelho.');
    }
    await authenticate();
    final mat = await _auth.lastMatricula();
    final senha = await _auth.lastSenha();
    if (mat == null || senha == null) {
      await _auth.setBiometricEnabled(false);
      throw BiometricException(
        'Credenciais biométricas não encontradas. Entre com matrícula e senha e ative a biometria de novo.',
      );
    }
    return _auth.login(matricula: mat, senha: senha);
  }
}
