import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/engagement/engagement_models.dart';
import 'package:livro_registro/data/engagement/engagement_store.dart';
import 'package:livro_registro/data/engagement/raffle_engine.dart';
import 'package:livro_registro/data/user_models.dart';
import 'package:livro_registro/services/auth_service.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/common.dart';

class RaffleTab extends StatefulWidget {
  const RaffleTab({super.key});

  @override
  State<RaffleTab> createState() => _RaffleTabState();
}

class _RaffleTabState extends State<RaffleTab> {
  final _selectedGroups = <String>{};
  var _criteria = const RaffleCriteria();
  List<RaffleWinner> _winners = [];
  int _poolSize = 0;
  late final ConfettiController _confetti;
  bool _drawing = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      if (user?.grupo != null && !(user!.role.seesAllClasses)) {
        setState(() => _selectedGroups.add(user.grupo!));
      } else if (state.groups.isNotEmpty) {
        setState(() => _selectedGroups.add(state.selectedGroup));
      }
      _refreshPool();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _refreshPool() {
    final state = context.read<AppState>();
    final store = context.read<EngagementStore>();
    final auth = context.read<AuthService>();
    final engine = RaffleEngine(
      state: state,
      store: store,
      teacherNames: RaffleEngine.teacherNamesFromUsers(
        auth.localUsersSnapshot,
      ),
    );
    final pool = engine.buildPool(
      groups: _selectedGroups,
      criteria: _criteria,
    );
    setState(() => _poolSize = pool.length);
  }

  Future<void> _pickDate() async {
    final initial = DateTime.tryParse(
          '${_criteria.attendanceDate ?? lastOrThisSunday()}T12:00:00',
        ) ??
        DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
      locale: const Locale('pt', 'BR'),
    );
    if (picked == null) return;
    setState(() {
      _criteria = _criteria.copyWith(
        attendanceDate: DateFormat('yyyy-MM-dd').format(picked),
        onlyPresentOnDate: true,
      );
    });
    _refreshPool();
  }

  Future<void> _draw() async {
    final auth = context.read<AuthService>();
    final role = auth.currentUser?.role ?? UserRole.aluno;
    if (!role.isStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apenas a equipe pode sortear.')),
      );
      return;
    }
    if (_selectedGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione ao menos uma turma.')),
      );
      return;
    }
    setState(() => _drawing = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final state = context.read<AppState>();
    final store = context.read<EngagementStore>();
    final engine = RaffleEngine(
      state: state,
      store: store,
      teacherNames: RaffleEngine.teacherNamesFromUsers(
        auth.localUsersSnapshot,
      ),
    );
    final winners = engine.draw(
      groups: _selectedGroups,
      criteria: _criteria,
    );
    setState(() {
      _winners = winners;
      _drawing = false;
      _poolSize = engine
          .buildPool(groups: _selectedGroups, criteria: _criteria)
          .length;
    });
    if (winners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum aluno elegível com estes critérios.'),
        ),
      );
      return;
    }
    _confetti.play();
    final entry = RaffleHistoryEntry(
      id: const Uuid().v4().replaceAll('-', '').substring(0, 12),
      at: DateTime.now(),
      groups: _selectedGroups.toList(),
      winners: winners,
      criteria: _criteria,
      trimestreKey: currentTrimestreKey(),
    );
    await store.addRaffle(entry);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final store = context.watch<EngagementStore>();
    final role = context.watch<AuthService>().currentUser?.role ?? UserRole.aluno;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Turmas no sorteio',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Base: alunos cadastrados nas classes selecionadas.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final g in state.groups)
                        FilterChip(
                          label: Text(g, style: const TextStyle(fontSize: 12)),
                          selected: _selectedGroups.contains(g),
                          selectedColor: AppColors.green.withValues(alpha: 0.25),
                          onSelected: role.seesAllClasses ||
                                  context.read<AuthService>().currentUser?.grupo ==
                                      null ||
                                  context.read<AuthService>().currentUser?.grupo ==
                                      g
                              ? (v) {
                                  setState(() {
                                    if (v) {
                                      _selectedGroups.add(g);
                                    } else {
                                      _selectedGroups.remove(g);
                                    }
                                  });
                                  _refreshPool();
                                }
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Critérios',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Só presentes na data'),
                    subtitle: Text(
                      _criteria.attendanceDate ?? lastOrThisSunday(),
                    ),
                    value: _criteria.onlyPresentOnDate,
                    onChanged: (v) {
                      setState(
                        () => _criteria = _criteria.copyWith(
                          onlyPresentOnDate: v,
                          attendanceDate:
                              _criteria.attendanceDate ?? lastOrThisSunday(),
                        ),
                      );
                      _refreshPool();
                    },
                  ),
                  if (_criteria.onlyPresentOnDate)
                    TextButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: const Text('Escolher data'),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Revista paga (trimestre atual)'),
                    value: _criteria.onlyMagazinePaid,
                    onChanged: (v) {
                      setState(
                        () => _criteria = _criteria.copyWith(
                          onlyMagazinePaid: v,
                          onlyMagazinePending:
                              v ? false : _criteria.onlyMagazinePending,
                        ),
                      );
                      _refreshPool();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Revista pendente (incentivo)'),
                    value: _criteria.onlyMagazinePending,
                    onChanged: (v) {
                      setState(
                        () => _criteria = _criteria.copyWith(
                          onlyMagazinePending: v,
                          onlyMagazinePaid:
                              v ? false : _criteria.onlyMagazinePaid,
                        ),
                      );
                      _refreshPool();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aniversariantes do mês'),
                    value: _criteria.onlyBirthdayMonth,
                    onChanged: (v) {
                      setState(
                        () => _criteria =
                            _criteria.copyWith(onlyBirthdayMonth: v),
                      );
                      _refreshPool();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Excluir quem já ganhou no trimestre'),
                    value: _criteria.excludePreviousWinners,
                    onChanged: (v) {
                      setState(
                        () => _criteria =
                            _criteria.copyWith(excludePreviousWinners: v),
                      );
                      _refreshPool();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Só com matrícula ou telefone'),
                    value: _criteria.requireMatriculaOrPhone,
                    onChanged: (v) {
                      setState(
                        () => _criteria =
                            _criteria.copyWith(requireMatriculaOrPhone: v),
                      );
                      _refreshPool();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Excluir professores/equipe'),
                    value: _criteria.excludeTeachers,
                    onChanged: (v) {
                      setState(
                        () =>
                            _criteria = _criteria.copyWith(excludeTeachers: v),
                      );
                      _refreshPool();
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Um ganhador por turma'),
                    subtitle: const Text('Em vez de sorteio global'),
                    value: _criteria.onePerClass,
                    onChanged: (v) {
                      setState(
                        () => _criteria = _criteria.copyWith(onePerClass: v),
                      );
                    },
                  ),
                  if (!_criteria.onePerClass) ...[
                    const Text('Quantidade de ganhadores'),
                    Slider(
                      value: _criteria.winnerCount.toDouble().clamp(1, 10),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '${_criteria.winnerCount}',
                      activeColor: AppColors.green,
                      onChanged: (v) {
                        setState(
                          () => _criteria =
                              _criteria.copyWith(winnerCount: v.round()),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Elegíveis agora: $_poolSize',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
            const SizedBox(height: 8),
            if (role.isStaff)
              FilledButton.icon(
                onPressed: _drawing ? null : _draw,
                icon: _drawing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.casino_outlined),
                label: Text(_drawing ? 'Sorteando…' : 'Sortear'),
              ),
            if (_winners.isNotEmpty) ...[
              const SizedBox(height: 16),
              SectionCard(
                child: Column(
                  children: [
                    const Text(
                      'Ganhador(es)',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final w in _winners)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.6, end: 1),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          builder: (ctx, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: AppColors.gold,
                              child: Icon(Icons.emoji_events, color: Colors.white),
                            ),
                            title: Text(
                              w.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            subtitle: Text(w.grupo),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (store.raffleHistory.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'Histórico',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (role.isStaff)
                    TextButton(
                      onPressed: () async {
                        await store.clearRaffleHistory();
                      },
                      child: const Text('Limpar'),
                    ),
                ],
              ),
              for (final h in store.raffleHistory.take(12))
                ListTile(
                  dense: true,
                  title: Text(
                    h.winners.map((w) => w.nome).join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${DateFormat("d/M/y HH:mm").format(h.at)} · ${h.groups.join(", ")}',
                  ),
                ),
            ],
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            colors: const [
              AppColors.gold,
              AppColors.green,
              AppColors.cream,
              AppColors.brown,
            ],
          ),
        ),
      ],
    );
  }
}
