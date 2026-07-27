import 'package:flutter/services.dart';

/// Canal nativo Android: SAF para gravar/abrir `ebd-backup.json` (Drive/arquivo).
class DriveBackupService {
  DriveBackupService();

  static const _channel = MethodChannel('br.com.ebd.livro_registro/backup');

  Future<String?> saveBackup({
    required List<int> bytes,
    String fileName = 'ebd-backup.json',
  }) async {
    return _channel.invokeMethod<String>('saveBackup', {
      'bytes': Uint8List.fromList(bytes),
      'fileName': fileName,
    });
  }

  Future<String?> pickBackup() async {
    return _channel.invokeMethod<String>('pickBackup');
  }
}
