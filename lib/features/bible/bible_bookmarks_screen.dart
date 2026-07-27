import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/bible/sample_texts.dart';
import 'package:livro_registro/features/bible/bible_reader_screen.dart';
import 'package:livro_registro/services/bible_repository.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class BibleBookmarksScreen extends StatelessWidget {
  const BibleBookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<BibleRepository>();

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'Marcadores'),
      body: repo.bookmarks.isEmpty && repo.highlights.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Toque em um versículo na leitura para marcar ou destacar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (repo.bookmarks.isNotEmpty) ...[
                  Text(
                    'Marcadores',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.brown,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final b in repo.bookmarks)
                    _ItemCard(
                      title:
                          '${bookById(b.bookId)?.name ?? b.bookId} ${b.chapter}:${b.verse}',
                      subtitle: 'Versão ${b.versionId}',
                      icon: Icons.bookmark,
                      iconColor: AppColors.green,
                      onOpen: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BibleReaderScreen(
                              bookId: b.bookId,
                              chapter: b.chapter,
                            ),
                          ),
                        );
                      },
                      onRemove: () => repo.removeBookmark(b.id),
                    ),
                  const SizedBox(height: 16),
                ],
                if (repo.highlights.isNotEmpty) ...[
                  Text(
                    'Destaques',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.brown,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final h in repo.highlights)
                    _ItemCard(
                      title:
                          '${bookById(h.bookId)?.name ?? h.bookId} ${h.chapter}:${h.verse}',
                      subtitle: 'Versão ${h.versionId}',
                      icon: Icons.highlight,
                      iconColor: AppColors.gold,
                      onOpen: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BibleReaderScreen(
                              bookId: h.bookId,
                              chapter: h.chapter,
                            ),
                          ),
                        );
                      },
                      onRemove: () => repo.toggleHighlight(
                        bookId: h.bookId,
                        chapter: h.chapter,
                        verse: h.verse,
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onOpen,
    required this.onRemove,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: AppColors.ink.withValues(alpha: 0.08)),
          ),
          leading: Icon(icon, color: iconColor),
          title: Text(title),
          subtitle: Text(subtitle),
          onTap: onOpen,
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: onRemove,
          ),
        ),
      ),
    );
  }
}
