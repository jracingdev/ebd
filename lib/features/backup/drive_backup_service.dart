import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Backup JSON: SAF no Android; file_picker / share nas demais plataformas.
class DriveBackupService {
  DriveBackupService();

  static const _channel = MethodChannel('br.com.ebd.livro_registro/backup');

  bool get supportsNativeSaf =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True se a plataforma tem seletor de arquivo para restore.
  bool get supportsRestore => true;

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

  /// Retorna o conteúdo JSON do backup escolhido, ou null se cancelado.
  Future<String?> pickBackup() async {
    if (supportsNativeSaf) {
      return _channel.invokeMethod<String>('pickBackup');
    }
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }
    final path = file.path;
    if (path == null) {
      throw UnsupportedError(
        'Não foi possível ler o arquivo selecionado nesta plataforma.',
      );
    }
    // Desktop / iOS com path: FilePicker já preenche bytes com withData.
    throw UnsupportedError(
      'Arquivo sem bytes. Tente novamente ou use um backup JSON menor.',
    );
  }
}
