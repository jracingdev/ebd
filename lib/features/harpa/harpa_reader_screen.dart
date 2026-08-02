import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:livro_registro/data/harpa/harpa_catalog.dart';
import 'package:livro_registro/data/harpa/harpa_models.dart';
import 'package:livro_registro/services/bible_tts_service.dart';
import 'package:livro_registro/services/harpa_repository.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

class HarpaReaderScreen extends StatefulWidget {
  const HarpaReaderScreen({super.key, required this.number});

  final int number;

  @override
  State<HarpaReaderScreen> createState() => _HarpaReaderScreenState();
}

class _HarpaReaderScreenState extends State<HarpaReaderScreen> {
  late int _number = widget.number;
  HarpaHymn? _hymn;
  String? _errorMessage;
  bool _missingLyrics = false;
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
    setState(() {
      _loading = true;
      _errorMessage = null;
      _missingLyrics = false;
    });
    final repo = context.read<HarpaRepository>();
    final result = await repo.loadHymn(_number);
    if (!mounted) return;
    setState(() {
      _hymn = result.hymn;
      _errorMessage = result.errorMessage;
      _missingLyrics = result.missingLyrics;
      _loading = false;
    });
  }

  Future<void> _go(int delta) async {
    final next = _number + delta;
    if (next < 1 || next > HarpaCatalog.maxNumber) return;
    await _tts.stop();
    setState(() {
      _speaking = false;
      _number = next;
    });
    await _load();
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    final hymn = _hymn;
    if (hymn == null || !hymn.hasLyrics) return;
    final repo = context.read<HarpaRepository>();
    await _tts.configure(
      speechRate: repo.prefs.ttsSpeechRate,
      preferredVoiceName: repo.prefs.ttsVoiceName,
    );
    setState(() => _speaking = true);
    await _tts.speak('Hino ${hymn.number}. ${hymn.title}. ${hymn.plainText}');
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _openCpad() async {
    final uri = Uri.parse(HarpaRepository.cpadInfoUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o site da CPAD.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<HarpaRepository>();
    final title = _hymn?.title ??
        repo.entryByNumber(_number)?.title ??
        'Hino $_number';
    final fav = repo.isFavorite(_number);

    return Scaffold(
      appBar: SecondaryAppBar(
        title: _number.toString().padLeft(3, '0'),
        actions: [
          IconButton(
            tooltip: fav ? 'Remover favorito' : 'Favoritar',
            onPressed: () => repo.toggleFavorite(_number),
            icon: Icon(
              fav ? Icons.favorite : Icons.favorite_border,
              color: fav ? AppColors.gold : null,
            ),
          ),
          IconButton(
            tooltip: _speaking ? 'Parar' : 'Ouvir',
            onPressed: (_hymn?.hasLyrics ?? false) ? _toggleSpeak : null,
            icon: Icon(
              _speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
            ),
          ),
        ],
      ),
      body: ResponsiveShell(
        maxWidth: 720,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.brown,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hino $_number · Harpa Cristã',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_missingLyrics ||
                            _hymn == null ||
                            !_hymn!.hasLyrics) ...[
                          SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline,
                                    color: AppColors.gold),
                                const SizedBox(height: 10),
                                Text(
                                  _errorMessage ??
                                      'Letra não disponível neste aparelho.',
                                  style: TextStyle(
                                    fontSize: repo.prefs.fontSize * 0.9,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: _load,
                                      icon: const Icon(Icons.refresh, size: 18),
                                      label: const Text('Tentar de novo'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: _openCpad,
                                      icon: const Icon(Icons.open_in_new,
                                          size: 18),
                                      label: const Text('Sobre a CPAD'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          for (final stanza in _hymn!.stanzas) ...[
                            if (stanza.isChorus)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  'Refrão',
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700,
                                    fontSize: repo.prefs.fontSize * 0.85,
                                  ),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: Text(
                                stanza.text.trim(),
                                style: TextStyle(
                                  fontSize: repo.prefs.fontSize,
                                  height: 1.45,
                                  fontStyle: stanza.isChorus
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                                ),
                              ),
                            ),
                          ],
                          if (_hymn!.sourceNote != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _hymn!.sourceNote!,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _number > 1 ? () => _go(-1) : null,
                              icon: const Icon(Icons.chevron_left),
                              label: const Text('Anterior'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _number < HarpaCatalog.maxNumber
                                  ? () => _go(1)
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                              label: const Text('Próximo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
