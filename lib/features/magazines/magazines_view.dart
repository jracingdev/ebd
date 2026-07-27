import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/betel_catalog.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/common.dart';

class MagazinesView extends StatelessWidget {
  const MagazinesView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final grupo = state.selectedGroup;
    final edition = state.currentEdition(grupo);
    final catalog = betelCatalog[grupo];

    if (edition == null) {
      return SectionCard(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Nenhuma revista cadastrada para $grupo ainda.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _cadastrarRevista(context, grupo, catalog),
              child: const Text('Cadastrar revista do trimestre'),
            ),
          ],
        ),
      );
    }

    final totals = editionTotalsOf(state.records, edition.id);
    return ListView(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(edition.trimestre,
                  style: Theme.of(context).textTheme.titleLarge),
              if (catalog != null)
                Text(catalog['revista']!,
                    style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Recebido: ${currency(totals.pago)}',
                      style: const TextStyle(
                          color: AppColors.green, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 16),
                  Text('Pendente: ${currency(totals.pendente)}',
                      style: const TextStyle(
                          color: AppColors.danger, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _novaEntrega(context, grupo, edition.id),
                child: Text('+ Nova entrega (${totals.count})'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final r in totals.items)
          Card(
            child: ListTile(
              title: Text(r.nome),
              subtitle: Text(currency(r.valor)),
              trailing: StatusStamp(
                pago: r.isPago,
                onTap: () => state.toggleDeliveryStatus(r.id),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _cadastrarRevista(
    BuildContext context,
    String grupo,
    Map<String, String>? catalog,
  ) async {
    final ctrl = TextEditingController(
      text: catalog?['trimestre'] ?? 'Trimestre 2026',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cadastrar revista do trimestre'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Trimestre (ex: 3º Trimestre 2026)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar revista')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppState>().addEdition(grupo: grupo, trimestre: ctrl.text);
    }
  }

  Future<void> _novaEntrega(BuildContext context, String grupo, String edicaoId) async {
    final nome = TextEditingController();
    final valor = TextEditingController(text: '25');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova entrega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(
              controller: valor,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valor (R\$)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true && context.mounted && nome.text.trim().isNotEmpty) {
      await context.read<AppState>().addDelivery(
            nome: nome.text,
            grupo: grupo,
            edicaoId: edicaoId,
            valor: double.tryParse(valor.text.replaceAll(',', '.')) ?? 25,
          );
    }
  }
}
