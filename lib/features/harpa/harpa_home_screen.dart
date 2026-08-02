import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/harpa/harpa_catalog.dart';
import 'package:livro_registro/data/harpa/harpa_models.dart';
import 'package:livro_registro/features/harpa/harpa_favorites_screen.dart';
import 'package:livro_registro/features/harpa/harpa_reader_screen.dart';
import 'package:livro_registro/features/harpa/harpa_search_screen.dart';
import 'package:livro_registro/services/harpa_repository.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

/// Hub da Harpa EBD — lista por número, busca, favoritos e leitor.
class HarpaHomeScreen extends StatefulWidget {
  const HarpaHomeScreen({super.key});

  @override
  State<HarpaHomeScreen> createState() => _HarpaHomeScreenState();
}

class _HarpaHomeScreenState extends State<HarpaHomeScreen> {
  final _searchCtrl = TextEditingController();
  bool _grid = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openReader(int number) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HarpaReaderScreen(number: number)),
    );
  }

  Future<void> _showFontSheet(HarpaRepository repo) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.cream,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tamanho da letra',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.brown,
                    ),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setLocal) {
                  final size = repo.prefs.fontSize;
                  return Column(
                    children: [
                      Text('${size.round()} pt',
                          style: TextStyle(fontSize: size)),
                      Slider(
                        value: size,
                        min: 14,
                        max: 28,
                        divisions: 14,
                        activeColor: AppColors.green,
                        onChanged: (v) async {
                          await repo.setFontSize(v);
                          setLocal(() {});
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showTtsSheet(HarpaRepository repo) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.cream,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: StatefulBuilder(
            builder: (context, setLocal) {
              final rate = repo.prefs.ttsSpeechRate;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Velocidade da voz (${rate.toStringAsFixed(2)})',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.brown,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'A leitura usa o motor TTS do aparelho (mesmo padrão da Bíblia EBD).',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  Slider(
                    value: rate.clamp(0.2, 0.75),
                    min: 0.2,
                    max: 0.75,
                    divisions: 11,
                    activeColor: AppColors.green,
                    onChanged: (v) async {
                      await repo.setTtsSpeechRate(v);
                      setLocal(() {});
                    },
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<HarpaRepository>();
    final last = repo.entryByNumber(repo.prefs.lastHymnNumber);
    final catalog = repo.catalog;

    return Scaffold(
      appBar: SecondaryAppBar(
        title: 'Harpa EBD',
        actions: [
          IconButton(
            tooltip: _grid ? 'Lista' : 'Grade',
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(_grid ? Icons.view_list_outlined : Icons.grid_view),
          ),
          IconButton(
            tooltip: 'Velocidade da voz',
            onPressed: () => _showTtsSheet(repo),
            icon: const Icon(Icons.record_voice_over_outlined),
          ),
          IconButton(
            tooltip: 'Tamanho da letra',
            onPressed: () => _showFontSheet(repo),
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
      body: ResponsiveShell(
        maxWidth: 720,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openReader(repo.prefs.lastHymnNumber),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Row(
                            children: [
                              const Icon(Icons.music_note,
                                  color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Continuar hino',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      last == null
                                          ? 'Abrir Harpa Cristã'
                                          : '${last.number}. ${last.title}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right,
                                  color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                        hintText: 'Buscar por número ou título…',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => HarpaSearchScreen(
                                  initialQuery: _searchCtrl.text,
                                ),
                              ),
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppColors.ink.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      onSubmitted: (q) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HarpaSearchScreen(initialQuery: q),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.favorite_border,
                            title: 'Favoritos',
                            subtitle: repo.favorites.isEmpty
                                ? 'Nenhum ainda'
                                : '${repo.favorites.length} hino(s)',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HarpaFavoritesScreen(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.search,
                            title: 'Buscar',
                            subtitle: 'Número ou título',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HarpaSearchScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hinos 1–${HarpaCatalog.maxNumber}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.brown,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (catalog.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.15,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final e = catalog[index];
                      return _NumberCell(
                        entry: e,
                        favorited: repo.isFavorite(e.number),
                        onTap: () => _openReader(e.number),
                      );
                    },
                    childCount: catalog.length,
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: catalog.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final e = catalog[index];
                    return _HymnTile(
                      entry: e,
                      favorited: repo.isFavorite(e.number),
                      onTap: () => _openReader(e.number),
                      onFavorite: () => repo.toggleFavorite(e.number),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.gold),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HymnTile extends StatelessWidget {
  const _HymnTile({
    required this.entry,
    required this.favorited,
    required this.onTap,
    required this.onFavorite,
  });

  final HarpaCatalogEntry entry;
  final bool favorited;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${entry.number}',
                  style: const TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                tooltip: favorited ? 'Remover favorito' : 'Favoritar',
                onPressed: onFavorite,
                icon: Icon(
                  favorited ? Icons.favorite : Icons.favorite_border,
                  color: favorited ? AppColors.gold : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({
    required this.entry,
    required this.favorited,
    required this.onTap,
  });

  final HarpaCatalogEntry entry;
  final bool favorited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: favorited
                  ? AppColors.gold.withValues(alpha: 0.5)
                  : AppColors.ink.withValues(alpha: 0.08),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${entry.number}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.green,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
