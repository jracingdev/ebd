import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/bible/bible_models.dart';
import 'package:livro_registro/data/bible/sample_texts.dart';
import 'package:livro_registro/services/bible_repository.dart';
import 'package:livro_registro/services/bible_tts_service.dart';
import 'package:livro_registro/theme/app_theme.dart';

class BibleReaderScreen extends StatefulWidget {
  const BibleReaderScreen({
    super.key,
    required this.bookId,
    required this.chapter,
  });

  final String bookId;
  final int chapter;

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  late final String _bookId = widget.bookId;
  late int _chapter = widget.chapter;
  BibleChapter? _chapterData;
  bool _loading = true;
  final _tts = BibleTtsService();
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = context.read<BibleRepository>();
    final data = await repo.loadChapter(_bookId, _chapter);
    await repo.rememberPlace(_bookId, _chapter);
    if (!mounted) return;
    setState(() {
      _chapterData = data;
      _loading = false;
    });
  }

  Future<void> _goChapter(int delta) async {
    final book = bookById(_bookId);
    if (book == null) return;
    final next = _chapter + delta;
    if (next < 1 || next > book.chapters) return;
    await _tts.stop();
    setState(() {
      _speaking = false;
      _chapter = next;
    });
    await _load();
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    final data = _chapterData;
    if (data == null || data.verses.isEmpty) return;
    final book = bookById(_bookId)?.name ?? _bookId;
    final buffer = StringBuffer('$book, capítulo $_chapter. ');
    for (final v in data.verses) {
      buffer.write('Versículo ${v.number}. ${v.text} ');
    }
    setState(() => _speaking = true);
    await _tts.speak(buffer.toString());
  }

  void _verseActions(BibleVerse verse) {
    final repo = context.read<BibleRepository>();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                repo.isBookmarked(verse.bookId, verse.chapter, verse.number)
                    ? Icons.bookmark
                    : Icons.bookmark_border,
                color: AppColors.green,
              ),
              title: Text(
                repo.isBookmarked(verse.bookId, verse.chapter, verse.number)
                    ? 'Remover marcador'
                    : 'Marcar versículo',
              ),
              onTap: () async {
                await repo.toggleBookmark(
                  bookId: verse.bookId,
                  chapter: verse.chapter,
                  verse: verse.number,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                repo.highlightFor(verse.bookId, verse.chapter, verse.number) !=
                        null
                    ? Icons.highlight
                    : Icons.highlight_outlined,
                color: AppColors.gold,
              ),
              title: Text(
                repo.highlightFor(verse.bookId, verse.chapter, verse.number) !=
                        null
                    ? 'Remover destaque'
                    : 'Destacar',
              ),
              onTap: () async {
                await repo.toggleHighlight(
                  bookId: verse.bookId,
                  chapter: verse.chapter,
                  verse: verse.number,
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over_outlined),
              title: const Text('Ler este versículo'),
              onTap: () async {
                Navigator.pop(ctx);
                setState(() => _speaking = true);
                await _tts.speak(
                  'Versículo ${verse.number}. ${verse.text}',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<BibleRepository>();
    final book = bookById(_bookId);
    final title = book == null ? 'Leitura' : '${book.name} $_chapter';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: _speaking ? 'Parar leitura' : 'Ler em voz alta',
            onPressed: _chapterData == null ? null : _toggleSpeak,
            icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined),
          ),
          IconButton(
            tooltip: 'Tamanho da letra',
            onPressed: () => _showFontSheet(context, repo),
            icon: const Icon(Icons.text_fields),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Text(
                  repo.version.shortLabel,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _chapter > 1 ? () => _goChapter(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Cap. $_chapter'),
                IconButton(
                  onPressed: book != null && _chapter < book.chapters
                      ? () => _goChapter(1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _chapterData == null
                    ? _EmptyChapter(bookName: book?.name ?? _bookId, chapter: _chapter)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        children: [
                          if (_chapterData!.sourceNote != null) ...[
                            Text(
                              _chapterData!.sourceNote!,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          for (final v in _chapterData!.verses)
                            _VerseRow(
                              verse: v,
                              fontSize: repo.prefs.fontSize,
                              bookmarked: repo.isBookmarked(
                                v.bookId,
                                v.chapter,
                                v.number,
                              ),
                              highlight: repo.highlightFor(
                                v.bookId,
                                v.chapter,
                                v.number,
                              ),
                              onTap: () => _verseActions(v),
                            ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  void _showFontSheet(BuildContext context, BibleRepository repo) {
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
}

class _VerseRow extends StatelessWidget {
  const _VerseRow({
    required this.verse,
    required this.fontSize,
    required this.bookmarked,
    required this.highlight,
    required this.onTap,
  });

  final BibleVerse verse;
  final double fontSize;
  final bool bookmarked;
  final BibleHighlight? highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? bg;
    if (highlight != null) {
      bg = AppColors.gold.withValues(alpha: 0.18);
    }
    return InkWell(
      onTap: onTap,
      onLongPress: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${verse.number}',
                style: TextStyle(
                  color: AppColors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: fontSize * 0.75,
                ),
              ),
            ),
            Expanded(
              child: Text(
                verse.text,
                style: TextStyle(fontSize: fontSize, height: 1.45),
              ),
            ),
            if (bookmarked)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.bookmark, size: 16, color: AppColors.green),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChapter extends StatelessWidget {
  const _EmptyChapter({required this.bookName, required this.chapter});

  final String bookName;
  final int chapter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 48, color: AppColors.muted),
          const SizedBox(height: 16),
          Text(
            '$bookName $chapter ainda não está na amostra local.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Disponíveis agora: Salmos 23 e João 1 (domínio público). '
            'Capítulos licenciados podem ser plugados depois — docs/BIBLIA.md.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}
