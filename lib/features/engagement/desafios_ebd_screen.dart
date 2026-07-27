import 'package:flutter/material.dart';
import 'package:livro_registro/features/engagement/gamification_tab.dart';
import 'package:livro_registro/features/engagement/quiz_tab.dart';
import 'package:livro_registro/features/engagement/raffle_tab.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

/// Hub com abas: Sorteios · Quiz · Placar.
class DesafiosEbdScreen extends StatefulWidget {
  const DesafiosEbdScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<DesafiosEbdScreen> createState() => _DesafiosEbdScreenState();
}

class _DesafiosEbdScreenState extends State<DesafiosEbdScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SecondaryAppBar(title: 'Desafios EBD'),
      body: Column(
        children: [
          Material(
            color: AppColors.cream,
            child: TabBar(
              controller: _tabs,
              labelColor: AppColors.green,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.gold,
              tabs: const [
                Tab(text: 'Sorteios'),
                Tab(text: 'Quiz'),
                Tab(text: 'Placar'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                RaffleTab(),
                QuizTab(),
                GamificationTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
