import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:livro_registro/theme/app_theme.dart';

class BirthdayOverlay extends StatefulWidget {
  const BirthdayOverlay({
    super.key,
    required this.nome,
    required this.onDone,
  });

  final String nome;
  final VoidCallback onDone;

  @override
  State<BirthdayOverlay> createState() => _BirthdayOverlayState();
}

class _BirthdayOverlayState extends State<BirthdayOverlay>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _left;
  late final ConfettiController _right;
  late final AnimationController _balloons;

  @override
  void initState() {
    super.initState();
    _left = ConfettiController(duration: const Duration(seconds: 4));
    _right = ConfettiController(duration: const Duration(seconds: 4));
    _balloons = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _left.play();
      _right.play();
    });
  }

  @override
  void dispose() {
    _left.dispose();
    _right.dispose();
    _balloons.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎈🎂🎆', style: TextStyle(fontSize: 42)),
                    const SizedBox(height: 12),
                    Text(
                      'Parabéns, ${widget.nome}!',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Que Deus continue abençoando a sua vida!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.ink,
                      ),
                      onPressed: widget.onDone,
                      child: const Text('Continuar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ConfettiWidget(
              confettiController: _left,
              blastDirection: -pi / 4,
              emissionFrequency: 0.08,
              numberOfParticles: 18,
              maxBlastForce: 30,
              minBlastForce: 10,
              gravity: 0.2,
              colors: const [
                AppColors.gold,
                AppColors.green,
                Colors.pinkAccent,
                Colors.lightBlue,
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ConfettiWidget(
              confettiController: _right,
              blastDirection: -3 * pi / 4,
              emissionFrequency: 0.08,
              numberOfParticles: 18,
              maxBlastForce: 30,
              minBlastForce: 10,
              gravity: 0.2,
              colors: const [
                AppColors.gold,
                AppColors.green,
                Colors.orange,
                Colors.purpleAccent,
              ],
            ),
          ),
          ...List.generate(6, (i) {
            final dx = (i + 1) / 7;
            return AnimatedBuilder(
              animation: _balloons,
              builder: (context, _) {
                final t = (_balloons.value + i * 0.12) % 1.0;
                return Positioned(
                  left: MediaQuery.sizeOf(context).width * dx - 12,
                  bottom: -40 + t * (MediaQuery.sizeOf(context).height + 80),
                  child: Text(
                    i.isEven ? '🎈' : '🎉',
                    style: TextStyle(fontSize: 22 + (i % 3) * 4.0),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}
