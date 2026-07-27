import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/features/finances/receipt_preview_screen.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/common.dart';

class FinancesView extends StatelessWidget {
  const FinancesView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final items = state.finances
        .where((f) => f.grupo == state.selectedGroup)
        .toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    final ofertas = items
        .where((f) => f.tipo == 'oferta')
        .fold<double>(0, (s, f) => s + f.valor);
    final doacoes = items
        .where((f) => f.tipo == 'doacao')
        .fold<double>(0, (s, f) => s + f.valor);

    return ListView(
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ofertas e doações',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Ofertas: ${currency(ofertas)}'),
              Text('Doações: ${currency(doacoes)}'),
              Text('Total: ${currency(ofertas + doacoes)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _lancar(context),
                child: const Text('+ Lançar oferta ou doação'),
              ),
            ],
          ),
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Nenhuma oferta ou doação lançada ainda para esta turma.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ),
        for (final f in items)
          Card(
            child: ListTile(
              title: Text(f.tipo == 'oferta' ? 'Oferta' : 'Doação'),
              subtitle: Text(
                  '${f.data}${f.descricao.isEmpty ? '' : ' — ${f.descricao}'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currency(f.valor),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    tooltip: 'Ver comprovante',
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    onPressed: () => previewFinanceReceipt(context, f),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _lancar(BuildContext context) async {
    final state = context.read<AppState>();
    final valor = TextEditingController();
    final desc = TextEditingController();
    var tipo = 'oferta';
    var gerarRecibo = true;
    final data = lastOrThisSunday();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Oferta do dia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: tipo,
                items: const [
                  DropdownMenuItem(value: 'oferta', child: Text('Oferta')),
                  DropdownMenuItem(value: 'doacao', child: Text('Doação')),
                ],
                onChanged: (v) => setLocal(() => tipo = v ?? 'oferta'),
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
              TextField(
                controller: valor,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              ),
              TextField(
                controller: desc,
                decoration:
                    const InputDecoration(labelText: 'Observação (opcional)'),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gerar recibo PDF (visualizar)'),
                value: gerarRecibo,
                onChanged: (v) => setLocal(() => gerarRecibo = v ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      final v = double.tryParse(valor.text.replaceAll(',', '.')) ?? 0;
      if (v <= 0) return;
      final entry = await state.addFinance(
        grupo: state.selectedGroup,
        data: data,
        tipo: tipo,
        valor: v,
        descricao: desc.text.trim(),
      );
      if (gerarRecibo && context.mounted) {
        await previewFinanceReceipt(context, entry);
      }
    }
  }
}
