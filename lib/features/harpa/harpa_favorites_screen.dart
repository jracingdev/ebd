import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/features/harpa/harpa_reader_screen.dart';
import 'package:livro_registro/services/harpa_repository.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class HarpaFavoritesScreen extends StatelessWidget {
  const HarpaFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<HarpaRepository>();
    final items = [
      for (final n in repo.favorites)
        (number: n, title: repo.entryByNumber(n)?.title ?? 'Hino $n'),
    ];

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'Favoritos'),
      body: ResponsiveShell(
        maxWidth: 720,
        child: items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Toque no coração na lista ou no leitor para favoritar hinos.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: AppColors.ink.withValues(alpha: 0.08),
                      ),
                    ),
                    tileColor: Colors.white,
                    leading: const Icon(Icons.favorite, color: AppColors.gold),
                    title: Text('${item.number}. ${item.title}'),
                    trailing: IconButton(
                      tooltip: 'Remover',
                      onPressed: () => repo.toggleFavorite(item.number),
                      icon: const Icon(Icons.close),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              HarpaReaderScreen(number: item.number),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
