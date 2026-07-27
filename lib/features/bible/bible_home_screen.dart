import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/bible/bible_models.dart';
import 'package:livro_registro/data/bible/sample_texts.dart';
import 'package:livro_registro/features/bible/bible_bookmarks_screen.dart';
import 'package:livro_registro/features/bible/bible_plans_screen.dart';
import 'package:livro_registro/features/bible/bible_reader_screen.dart';
import 'package:livro_registro/features/bible/bible_search_screen.dart';
import 'package:livro_registro/services/bible_repository.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

/// Entrada da Bíblia EBD — visual alinhado ao livro de registro (creme/verde/ouro).
class BibleHomeScreen extends StatelessWidget {
  const BibleHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<BibleRepository>();
    final lastBook = bookById(repo.prefs.lastBookId);

    return Scaffold(
      appBar: const SecondaryAppBar(title: 'Bíblia EBD'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para a Escola Bíblica Dominical',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Leitura, marcadores e planos pensados para a preparação '
                  'das lições. O controle de revistas, ofertas e presença '
                  'continua no início do app.',
                  style: TextStyle(color: AppColors.muted, height: 1.35),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Text(
                    'Amostras em domínio público (Almeida 1819). '
                    'Versões ARA, RA, SBB e NTLH exigem licença — '
                    'veja a documentação do módulo.',
                    style: TextStyle(fontSize: 12, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Versão',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.brown,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in BibleVersion.values)
                ChoiceChip(
                  label: Text(v.shortLabel),
                  selected: repo.version == v,
                  onSelected: (_) => repo.setVersion(v),
                  selectedColor: AppColors.green,
                  labelStyle: TextStyle(
                    color: repo.version == v ? Colors.white : AppColors.ink,
                    fontSize: 13,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            repo.version.label,
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BibleReaderScreen(
                    bookId: repo.prefs.lastBookId,
                    chapter: repo.prefs.lastChapter,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_stories_outlined),
            label: Text(
              lastBook == null
                  ? 'Continuar leitura'
                  : 'Continuar · ${lastBook.name} ${repo.prefs.lastChapter}',
            ),
          ),
          const SizedBox(height: 12),
          _NavTile(
            icon: Icons.menu_book_outlined,
            title: 'Livros',
            subtitle: 'Antigo e Novo Testamento',
            onTap: () => _openBookPicker(context, repo),
          ),
          _NavTile(
            icon: Icons.search,
            title: 'Buscar trechos',
            subtitle: 'Nas amostras disponíveis',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BibleSearchScreen()),
            ),
          ),
          _NavTile(
            icon: Icons.calendar_today_outlined,
            title: 'Minha leitura',
            subtitle: 'Planos curtos para a EBD',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BiblePlansScreen()),
            ),
          ),
          _NavTile(
            icon: Icons.bookmark_border,
            title: 'Marcadores',
            subtitle: 'Versículos e destaques salvos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BibleBookmarksScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBookPicker(
    BuildContext context,
    BibleRepository repo,
  ) async {
    final book = await showModalBottomSheet<BibleBook>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final at = repo.books.where((b) => b.testament == 'AT').toList();
        final nt = repo.books.where((b) => b.testament == 'NT').toList();
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.92,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.muted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Escolher livro',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Antigo Testamento',
                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
              ),
              ...at.map(
                (b) => ListTile(
                  title: Text(b.name),
                  trailing: Text(
                    '${b.chapters} cap.',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(ctx, b),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Novo Testamento',
                style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600),
              ),
              ...nt.map(
                (b) => ListTile(
                  title: Text(b.name),
                  trailing: Text(
                    '${b.chapters} cap.',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  onTap: () => Navigator.pop(ctx, b),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (book == null || !context.mounted) return;

    final chapter = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text(book.name),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 1; i <= book.chapters; i++)
                ActionChip(
                  label: Text('$i'),
                  onPressed: () => Navigator.pop(ctx, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (chapter == null || !context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(bookId: book.id, chapter: chapter),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
