import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Backup JSON: SAF no Android; compartilhar/download nas demais plataformas.
class DriveBackupService {
  DriveBackupService();

  static const _channel = MethodChannel('br.com.ebd.livro_registro/backup');

  bool get supportsNativeSaf =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<String?> saveBackup({
    required List<int> bytes,
    String fileName = 'ebd-backup.json',
  }) async {
    if (!supportsNativeSaf) {
      final data = Uint8List.fromList(bytes);
      await Share.shareXFiles(
        [
          XFile.fromData(
            data,
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
        subject: 'Backup EBD',
        text: 'Backup do livro de registro EBD',
      );
      return fileName;
    }
    return _channel.invokeMethod<String>('saveBackup', {
      'bytes': Uint8List.fromList(bytes),
      'fileName': fileName,
    });
  }

  Future<String?> pickBackup() async {
    if (!supportsNativeSaf) {
      throw UnsupportedError(
        'Restaurar de arquivo pelo seletor nativo está disponível no Android. '
        'Na web/iOS, use um aparelho Android ou importe o JSON via fluxo nativo.',
      );
    }
    return _channel.invokeMethod<String>('pickBackup');
  }
}
