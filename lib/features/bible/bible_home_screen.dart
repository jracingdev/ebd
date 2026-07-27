import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/bible/bible_catalog.dart';
import 'package:livro_registro/data/bible/bible_models.dart';
import 'package:livro_registro/features/bible/bible_bookmarks_screen.dart';
import 'package:livro_registro/features/bible/bible_plans_screen.dart';
import 'package:livro_registro/features/bible/bible_reader_screen.dart';
import 'package:livro_registro/features/bible/bible_search_screen.dart';
import 'package:livro_registro/services/bible_repository.dart';
import 'package:livro_registro/services/bible_tts_service.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

/// Hub da Bíblia EBD — atalhos de uso, sem mural de disclaimer.
class BibleHomeScreen extends StatefulWidget {
  const BibleHomeScreen({super.key});

  @override
  State<BibleHomeScreen> createState() => _BibleHomeScreenState();
}

class _BibleHomeScreenState extends State<BibleHomeScreen> {
  final _tts = BibleTtsService();
  final _searchCtrl = TextEditingController();
  bool _speaking = false;
  BibleVerse? _spotlight;
  String? _spotlightLabel;
  bool _spotlightLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVerseOfDay());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tts.dispose();
    super.dispose();
  }

  Future<void> _loadVerseOfDay() async {
    setState(() => _spotlightLoading = true);
    final repo = context.read<BibleRepository>();
    final day = DateTime.now();
    final seed = day.year * 1000 + day.month * 40 + day.day;
    final verse = await _pickVerse(repo, seed);
    if (!mounted) return;
    setState(() {
      _spotlight = verse;
      _spotlightLabel = 'Versículo do dia';
      _spotlightLoading = false;
    });
  }

  Future<void> _loadRandomVerse() async {
    setState(() => _spotlightLoading = true);
    final repo = context.read<BibleRepository>();
    final verse = await _pickVerse(repo, Random().nextInt(1 << 30));
    if (!mounted) return;
    setState(() {
      _spotlight = verse;
      _spotlightLabel = 'Versículo sorteado';
      _spotlightLoading = false;
    });
  }

  Future<BibleVerse?> _pickVerse(BibleRepository repo, int seed) async {
    final rng = Random(seed);
    for (var attempt = 0; attempt < 12; attempt++) {
      final book = kBibleBooks[rng.nextInt(kBibleBooks.length)];
      final chapter = 1 + rng.nextInt(book.chapters);
      final load = await repo.loadChapter(book.id, chapter);
      final verses = load.chapter?.verses;
      if (verses == null || verses.isEmpty) continue;
      return verses[rng.nextInt(verses.length)];
    }
    return null;
  }

  void _openReader(String bookId, int chapter) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(bookId: bookId, chapter: chapter),
      ),
    );
  }

  Future<void> _speakCurrentChapter() async {
    final repo = context.read<BibleRepository>();
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    final load = await repo.loadChapter(
      repo.prefs.lastBookId,
      repo.prefs.lastChapter,
    );
    final data = load.chapter;
    if (data == null || data.verses.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            load.errorMessage ??
                'Não foi possível carregar o capítulo para ouvir.',
          ),
        ),
      );
      return;
    }
    final book = bookById(data.bookId)?.name ?? data.bookId;
    final buffer = StringBuffer('$book, capítulo ${data.chapter}. ');
    for (final v in data.verses) {
      buffer.write('Versículo ${v.number}. ${v.text} ');
    }
    setState(() => _speaking = true);
    await _tts.speak(buffer.toString());
  }

  void _showFontSheet(BibleRepository repo) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tamanho da letra',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Slider(
                  value: repo.prefs.fontSize,
                  min: 14,
                  max: 28,
                  divisions: 14,
                  label: repo.prefs.fontSize.round().toString(),
                  activeColor: AppColors.green,
                  onChanged: (v) async {
                    await repo.setFontSize(v);
                    setModal(() {});
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  ReadingPlanDay? _planDayToday(BibleRepository repo) {
    if (repo.plans.isEmpty) return null;
    final plan = repo.plans.first;
    final progress = repo.progressFor(plan.id);
    for (final day in plan.days) {
      if (!progress.completedDays.contains(day.day)) return day;
    }
    return plan.days.isEmpty ? null : plan.days.last;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<BibleRepository>();
    final lastBook = bookById(repo.prefs.lastBookId);
    final planDay = _planDayToday(repo);
    final recentMarks = repo.bookmarks.take(3).toList();
    final downloading = repo.downloadProgress[repo.version.id];

    return Scaffold(
      appBar: SecondaryAppBar(
        title: 'Bíblia EBD',
        actions: [
          IconButton(
            tooltip: 'Tamanho da letra',
            onPressed: () => _showFontSheet(repo),
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Continuar leitura
          Material(
            color: AppColors.green,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openReader(
                repo.prefs.lastBookId,
                repo.prefs.lastChapter,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Row(
                  children: [
                    const Icon(Icons.auto_stories, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Continuar leitura',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lastBook == null
                                ? 'Abrir a Bíblia'
                                : '${lastBook.name} ${repo.prefs.lastChapter}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _speaking ? 'Parar' : 'Ouvir capítulo',
                      onPressed: _speakCurrentChapter,
                      icon: Icon(
                        _speaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Versão compacta
          Row(
            children: [
              Text(
                'Versão',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.brown,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              if (repo.version.isRemote && downloading == null)
                TextButton.icon(
                  onPressed: repo.isVersionFullyCached(repo.version.id)
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Baixando ${repo.version.shortLabel}…',
                              ),
                            ),
                          );
                          await repo.downloadCurrentVersionOffline();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                repo.isVersionFullyCached(repo.version.id)
                                    ? 'Pronta offline.'
                                    : 'Download parcial — tente de novo.',
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: Text(
                    repo.isVersionFullyCached(repo.version.id)
                        ? 'Offline'
                        : 'Baixar',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final v in BibleVersion.values) ...[
                  ChoiceChip(
                    label: Text(v.shortLabel),
                    selected: repo.version == v,
                    onSelected: (_) => repo.setVersion(v),
                    selectedColor: AppColors.green,
                    visualDensity: VisualDensity.compact,
                    labelStyle: TextStyle(
                      color: repo.version == v ? Colors.white : AppColors.ink,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          if (downloading != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: downloading,
              color: AppColors.green,
              backgroundColor: AppColors.green.withValues(alpha: 0.15),
            ),
          ],
          const SizedBox(height: 14),

          // Busca rápida
          TextField(
            controller: _searchCtrl,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Buscar palavra ou referência…',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BibleSearchScreen(),
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
                  builder: (_) => BibleSearchScreen(initialQuery: q),
                ),
              );
            },
            onTap: () {
              // Abre busca dedicada ao focar, se preferir manter campo só como atalho.
            },
          ),
          const SizedBox(height: 14),

          // Grade de atalhos
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.menu_book_outlined,
                  title: 'Livros',
                  subtitle: 'AT e NT',
                  onTap: () => _openBookPicker(context, repo),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.account_balance_outlined,
                  title: 'Testamentos',
                  subtitle: 'Escolher seção',
                  onTap: () => _openTestamentPicker(context, repo),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.calendar_today_outlined,
                  title: 'Plano do dia',
                  subtitle: planDay == null
                      ? 'Minha leitura'
                      : (planDay.title ??
                          '${bookById(planDay.bookId)?.name ?? planDay.bookId} ${planDay.chapter}'),
                  onTap: () {
                    if (planDay != null) {
                      _openReader(planDay.bookId, planDay.chapter);
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BiblePlansScreen(),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.bookmark_border,
                  title: 'Marcadores',
                  subtitle: recentMarks.isEmpty
                      ? 'Nenhum ainda'
                      : '${recentMarks.length} recente(s)',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BibleBookmarksScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionTile(
                  icon: Icons.casino_outlined,
                  title: 'Sortear',
                  subtitle: 'Versículo',
                  onTap: _loadRandomVerse,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionTile(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Do dia',
                  subtitle: 'Atualizar',
                  onTap: _loadVerseOfDay,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Spotlight: versículo do dia / sorteado
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _spotlightLabel ?? 'Versículo do dia',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.brown,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    if (_spotlight != null)
                      IconButton(
                        tooltip: 'Ouvir',
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final b = bookById(_spotlight!.bookId)?.name ??
                              _spotlight!.bookId;
                          await _tts.speak(
                            '$b ${_spotlight!.chapter}:${_spotlight!.number}. ${_spotlight!.text}',
                          );
                        },
                        icon: const Icon(Icons.volume_up_outlined, size: 20),
                      ),
                  ],
                ),
                if (_spotlightLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_spotlight == null)
                  const Text(
                    'Toque em “Do dia” ou “Sortear” para ver um versículo.',
                    style: TextStyle(color: AppColors.muted),
                  )
                else ...[
                  Text(
                    '${bookById(_spotlight!.bookId)?.name ?? _spotlight!.bookId} '
                    '${_spotlight!.chapter}:${_spotlight!.number}',
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _spotlight!.text,
                    style: TextStyle(
                      fontSize: repo.prefs.fontSize * 0.95,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _openReader(
                        _spotlight!.bookId,
                        _spotlight!.chapter,
                      ),
                      child: const Text('Abrir capítulo'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (recentMarks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Marcadores recentes',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.brown,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            for (final b in recentMarks)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: AppColors.ink.withValues(alpha: 0.08),
                      ),
                    ),
                    leading: const Icon(Icons.bookmark, color: AppColors.green),
                    title: Text(
                      '${bookById(b.bookId)?.name ?? b.bookId} ${b.chapter}:${b.verse}',
                    ),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                    onTap: () => _openReader(b.bookId, b.chapter),
                  ),
                ),
              ),
          ],

          const SizedBox(height: 8),
          _NavTile(
            icon: Icons.search,
            title: 'Busca completa',
            subtitle: 'Lista de resultados na versão atual',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BibleSearchScreen()),
            ),
          ),
          _NavTile(
            icon: Icons.calendar_month_outlined,
            title: 'Minha leitura',
            subtitle: 'Planos da semana EBD',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BiblePlansScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTestamentPicker(
    BuildContext context,
    BibleRepository repo,
  ) async {
    final testament = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history_edu_outlined, color: AppColors.green),
              title: const Text('Antigo Testamento'),
              subtitle: Text(
                '${repo.books.where((b) => b.testament == 'AT').length} livros',
              ),
              onTap: () => Navigator.pop(ctx, 'AT'),
            ),
            ListTile(
              leading: const Icon(Icons.church_outlined, color: AppColors.green),
              title: const Text('Novo Testamento'),
              subtitle: Text(
                '${repo.books.where((b) => b.testament == 'NT').length} livros',
              ),
              onTap: () => Navigator.pop(ctx, 'NT'),
            ),
          ],
        ),
      ),
    );
    if (testament == null || !context.mounted) return;
    await _openBookPicker(context, repo, onlyTestament: testament);
  }

  Future<void> _openBookPicker(
    BuildContext context,
    BibleRepository repo, {
    String? onlyTestament,
  }) async {
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
              Text(
                onlyTestament == null
                    ? 'Escolher livro'
                    : (onlyTestament == 'AT'
                        ? 'Antigo Testamento'
                        : 'Novo Testamento'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              const SizedBox(height: 12),
              if (onlyTestament == null || onlyTestament == 'AT') ...[
                if (onlyTestament == null)
                  const Text(
                    'Antigo Testamento',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
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
              ],
              if (onlyTestament == null || onlyTestament == 'NT') ...[
                if (onlyTestament == null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Novo Testamento',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
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
    _openReader(book.id, chapter);
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.green, size: 22),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
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
