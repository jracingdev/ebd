import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:livro_registro/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final _siteUri = Uri.parse('https://jracing.dev.br');

  Future<void> _openSite(BuildContext context) async {
    final opened = await launchUrl(
      _siteUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o site.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
              children: [
                const Icon(
                  Icons.menu_book_outlined,
                  size: 54,
                  color: AppColors.green,
                ),
                const SizedBox(height: 16),
                Text(
                  'EBD',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Escola Bíblica Dominical',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 40),
                const _SectionTitle('Desenvolvimento'),
                const SizedBox(height: 10),
                const Text(
                  'Desenvolvido por J Racing Dev',
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Grupo J Racing — desde 2005',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Desenvolvimento digital e engenharia de software aplicada a negócios.',
                  style: TextStyle(height: 1.45),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openSite(context),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('jracing.dev.br'),
                  ),
                ),
                const SizedBox(height: 32),
                const _SectionTitle('Versão do app'),
                const SizedBox(height: 10),
                FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Text(
                        'Carregando versão...',
                        style: TextStyle(color: AppColors.muted),
                      );
                    }
                    final info = snapshot.data!;
                    return Text(
                      '${info.version} (${info.buildNumber})',
                      style: const TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}
