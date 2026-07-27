import 'package:flutter/material.dart';
import 'package:livro_registro/theme/app_theme.dart';

/// AppBar de telas empilhadas: volta (pop) + atalho Início até a raiz.
class SecondaryAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SecondaryAppBar({super.key, required this.title, this.actions});

  final String title;
  final List<Widget>? actions;

  void _goHome(BuildContext context) {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.popUntil((route) => route.isFirst);
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      title: Text(title),
      automaticallyImplyLeading: canPop,
      actions: [
        ...?actions,
        if (canPop)
          TextButton.icon(
            onPressed: () => _goHome(context),
            icon: const Icon(Icons.home_outlined, size: 20),
            label: const Text('Início'),
          ),
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class StatusStamp extends StatelessWidget {
  const StatusStamp({super.key, required this.pago, this.onTap});

  final bool pago;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = pago ? AppColors.green : AppColors.danger;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(3),
          color: color.withValues(alpha: 0.06),
        ),
        child: Text(
          pago ? 'Pago' : 'Pendente',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
