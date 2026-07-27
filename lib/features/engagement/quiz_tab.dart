import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/engagement/engagement_models.dart';
import 'package:livro_registro/data/engagement/engagement_store.dart';
import 'package:livro_registro/data/engagement/quiz_bank.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

/// Quiz bíblico com níveis e recordes locais.
class QuizTab extends StatefulWidget {
  const QuizTab({super.key});

  @override
  State<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> {
  static const _roundSizes = [10, 20, 30, 50];

  QuizBank? _bank;
  String? _loadError;
  QuizLevel _level = QuizLevel.facil;
  int _roundSize = 10;
  List<QuizQuestion> _session = [];
  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _revealed = false;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _loadBank();
  }

  Future<void> _loadBank() async {
    try {
      final bank = await QuizBank.load();
      if (!mounted) return;
      setState(() {
        _bank = bank;
        _loadError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = 'Não foi possível carregar o quiz: $e');
    }
  }

  int get _availableForLevel {
    final bank = _bank;
    if (bank == null) return 0;
    return bank.availableCount(level: _level);
  }

  void _start() {
    final bank = _bank;
    if (bank == null) return;
    final result = bank.pickRound(level: _level, count: _roundSize);
    if (result.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sem perguntas no nível ${_level.label}.')),
      );
      return;
    }
    if (result.usedFullPool) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Só há ${result.poolSize} pergunta${result.poolSize == 1 ? '' : 's'} '
            'neste nível. A rodada usará todas.',
          ),
        ),
      );
    }
    setState(() {
      _session = result.questions;
      _index = 0;
      _score = 0;
      _selected = null;
      _revealed = false;
      _finished = false;
    });
  }

  Future<void> _answer(int optionIndex) async {
    if (_revealed || _finished || _session.isEmpty) return;
    final q = _session[_index];
    final ok = optionIndex == q.correctIndex;
    setState(() {
      _selected = optionIndex;
      _revealed = true;
      if (ok) _score++;
    });
  }

  Future<void> _next() async {
    if (_index + 1 >= _session.length) {
      final store = context.read<EngagementStore>();
      await store.saveQuizBest(
        QuizBestScore(
          level: _level,
          score: _score,
          total: _session.length,
          at: DateTime.now(),
        ),
      );
      if (!mounted) return;
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<EngagementStore>();

    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_bank == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_finished) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              children: [
                Text(
                  'Resultado',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '$_score / ${_session.length}',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  'Nível ${_level.label}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _start,
                  child: const Text('Jogar de novo'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _session = [];
                    _finished = false;
                  }),
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_session.isNotEmpty) {
      final q = _session[_index];
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Pergunta ${_index + 1} de ${_session.length} · ${_level.label}',
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.question, style: Theme.of(context).textTheme.titleMedium),
                if (q.reference != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    q.reference!,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                for (var i = 0; i < q.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        foregroundColor: AppColors.ink,
                        side: BorderSide(
                          color: !_revealed
                              ? AppColors.muted.withValues(alpha: 0.4)
                              : i == q.correctIndex
                                  ? AppColors.green
                                  : i == _selected
                                      ? AppColors.danger
                                      : AppColors.muted.withValues(alpha: 0.3),
                        ),
                        backgroundColor: !_revealed
                            ? null
                            : i == q.correctIndex
                                ? AppColors.green.withValues(alpha: 0.12)
                                : i == _selected
                                    ? AppColors.danger.withValues(alpha: 0.08)
                                    : null,
                      ),
                      onPressed: _revealed ? null : () => _answer(i),
                      child: Text(q.options[i]),
                    ),
                  ),
                if (_revealed)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(
                        _index + 1 >= _session.length ? 'Ver resultado' : 'Próxima',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    final available = _availableForLevel;
    final effectiveRound = available == 0
        ? 0
        : (_roundSize > available ? available : _roundSize);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nível', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final level in QuizLevel.values)
                    ChoiceChip(
                      label: Text(level.label),
                      selected: _level == level,
                      selectedColor: AppColors.green,
                      labelStyle: TextStyle(
                        color: _level == level ? Colors.white : AppColors.ink,
                      ),
                      onSelected: (_) => setState(() => _level = level),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Perguntas na rodada',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final size in _roundSizes)
                    ChoiceChip(
                      label: Text('$size'),
                      selected: _roundSize == size,
                      selectedColor: AppColors.green,
                      labelStyle: TextStyle(
                        color: _roundSize == size ? Colors.white : AppColors.ink,
                      ),
                      onSelected: (_) => setState(() => _roundSize = size),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                available == 0
                    ? 'Nenhuma pergunta neste nível.'
                    : available < _roundSize
                        ? 'Disponíveis neste nível: $available '
                            '(a rodada usará todas).'
                        : 'Disponíveis neste nível: $available · '
                            'Rodada: $effectiveRound perguntas aleatórias.',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: available == 0 ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  effectiveRound == 0
                      ? 'Iniciar quiz'
                      : 'Iniciar quiz ($effectiveRound perguntas)',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Seus recordes', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (store.quizBest.isEmpty)
                const Text(
                  'Ainda sem recordes. Complete um quiz para registrar.',
                  style: TextStyle(color: AppColors.muted),
                )
              else
                for (final e in store.quizBest.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.key.label),
                    subtitle: Text(
                      '${e.value.score}/${e.value.total} '
                      '(${(e.value.ratio * 100).round()}%)',
                    ),
                    trailing: Text(
                      '${e.value.at.day}/${e.value.at.month}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
