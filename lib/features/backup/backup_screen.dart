import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/config/app_config.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/data/permissions.dart';
import 'package:livro_registro/features/backup/drive_backup_service.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/services/cloud_sync_service.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _service = DriveBackupService();
  final _cloud = CloudSyncService();
  String? _lastPath;
  String? _lastSyncSummary;
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthService>();
      final backup = context.read<AppState>().exportBackup(
            users: auth.exportUsersForBackup(),
          );
      final bytes = utf8.encode(
        const JsonEncoder.withIndent('  ').convert(backup.toJson()),
      );
      final path = await _service.saveBackup(bytes: bytes);
      if (!mounted) return;
      setState(() => _lastPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null ? 'Backup cancelado.' : 'Backup salvo em $path',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar backup: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup?'),
        content: const Text(
          'Isso substitui todos os dados locais pelo arquivo escolhido '
          '(por exemplo, um backup no Google Drive). '
          'Perfis e permissões também são restaurados quando presentes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final jsonStr = await _service.pickBackup();
      if (jsonStr == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum backup selecionado.')),
        );
        return;
      }
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final backup = AppBackup.fromJson(map);
      if (!mounted) return;
      await context.read<AppState>().importBackup(backup);
      if (!mounted) return;
      if (backup.users.isNotEmpty) {
        await context.read<AuthService>().importUsersFromBackup(backup.users);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Arquivo inválido. Selecione um backup ebd-backup.json. ($e)',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cloudSync() async {
    setState(() => _busy = true);
    try {
      final result = await _cloud.syncAll(context.read<AppState>());
      if (!mounted) return;
      setState(() => _lastSyncSummary = result.summary);
      final msg = result.warnings.isEmpty
          ? 'Sincronizado: ${result.summary}'
          : 'Sync parcial: ${result.summary}\n${result.warnings.join('\n')}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha na sincronização: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final canSyncCloud = AppConfig.supabaseConfigured &&
        auth.usingSupabase &&
        userHasPermission(auth.currentUser, AppPermission.backup);

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'Backup EBD'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Backup do app EBD',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'GOOGLE DRIVE / ARQUIVO',
            style: TextStyle(
              color: AppColors.gold,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _service.supportsNativeSaf
                ? 'Como usar no Drive'
                : 'Compartilhar e restaurar',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_service.supportsNativeSaf) ...[
            const Text('1. Toque em Fazer backup'),
            const Text(
              '2. No seletor, abra o Google Drive e escolha a pasta',
            ),
            const Text(
              '3. Para restaurar, escolha o arquivo ebd-backup.json no Drive',
            ),
          ] else ...[
            const Text(
              'Nesta plataforma o backup é compartilhado/baixado como '
              'ebd-backup.json. Para restaurar, use o botão abaixo e '
              'escolha o arquivo JSON (web, iOS ou desktop).',
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _export,
            child: const Text('Fazer backup'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy ? null : _import,
            child: Text(
              _service.supportsNativeSaf
                  ? 'Restaurar de arquivo / Drive'
                  : 'Restaurar de arquivo JSON',
            ),
          ),
          if (canSyncCloud) ...[
            const SizedBox(height: 28),
            const Text(
              'NUVEM SUPABASE',
              style: TextStyle(
                color: AppColors.gold,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Envia e baixa alunos, presença e ofertas (merge por id). '
              'Edições/Betel estão pausados no sync cloud até o hot-fix '
              'não-destrutivo. Lições, entregas e engagement também ficam de fora.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: _busy ? null : _cloudSync,
              icon: const Icon(Icons.sync),
              label: const Text('Sincronizar com a nuvem'),
            ),
            if (_lastSyncSummary != null) ...[
              const SizedBox(height: 8),
              Text(
                'Última sync: $_lastSyncSummary',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ],
          if (_lastPath != null) ...[
            const SizedBox(height: 16),
            Text(
              'Último backup neste aparelho: $_lastPath',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
