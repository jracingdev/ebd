import 'package:flutter/material.dart';
import 'package:livro_registro/theme/app_theme.dart';

/// Breakpoints simples para shell web/tablet.
class AppBreakpoints {
  static const double compact = 600;
  static const double medium = 900;
  static const double contentMax = 1100;
}

/// Centraliza conteúdo em telas largas (web/tablet) sem redesign.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMax,
    this.padding,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );
  }
}

/// Altura baixa típica de telefone em landscape (~360–480 dp).
bool isShortViewport(BuildContext context, {double threshold = 520}) {
  return MediaQuery.sizeOf(context).height < threshold;
}

/// Preenche a altura disponível e faz scroll se o conteúdo não couber
/// (evita RenderFlex overflow em landscape).
class ScrollableFill extends StatelessWidget {
  const ScrollableFill({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite ? constraints.maxHeight : 0.0;
        Widget body = ConstrainedBox(
          constraints: BoxConstraints(minHeight: h),
          child: child,
        );
        if (padding != null) {
          body = Padding(padding: padding!, child: body);
        }
        return SingleChildScrollView(child: body);
      },
    );
  }
}

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
