import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/utils/format.dart';

Future<void> printEbdReport(BuildContext context) async {
  final state = context.read<AppState>();
  final doc = await buildEbdReportPdf(state);
  await Printing.layoutPdf(
    onLayout: (_) async => doc.save(),
    name: 'relatorio-geral-ebd',
  );
}

Future<pw.Document> buildEbdReportPdf(AppState state) async {
  final doc = pw.Document();
  final gerado = formatDate(DateTime.now());
  final blocks = <_Block>[];

  for (final g in state.groups) {
    final edition = state.currentEdition(g);
    final finItems = state.finances.where((f) => f.grupo == g).toList();
    final att = state.attendance.where((a) => a.grupo == g).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    if (edition == null && finItems.isEmpty && att.isEmpty) continue;
    final totals = edition == null
        ? null
        : editionTotalsOf(state.records, edition.id);
    blocks.add(_Block(
      grupo: g,
      edition: edition,
      totals: totals,
      finances: finItems,
      attendance: att.take(3).toList(),
    ));
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Text('ESCOLA BÍBLICA DOMINICAL',
            style: pw.TextStyle(
              fontSize: 10,
              letterSpacing: 1.4,
              color: PdfColor.fromInt(0xFFB8892B),
            )),
        pw.Text('Relatório geral',
            style: pw.TextStyle(fontSize: 22, fontStyle: pw.FontStyle.italic)),
        pw.Text('Gerado em $gerado',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.SizedBox(height: 16),
        if (blocks.isEmpty)
          pw.Text('Nada cadastrado ainda para gerar relatório.')
        else
          for (final b in blocks) ...[
            pw.Text(
              '${b.grupo}${b.edition != null ? ' — ${b.edition!.trimestre}' : ''}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            if (b.edition == null)
              pw.Text('Sem revista cadastrada.',
                  style: const pw.TextStyle(color: PdfColors.grey600))
            else if (b.totals!.items.isEmpty)
              pw.Text('Sem entregas de revista registradas.',
                  style: const pw.TextStyle(color: PdfColors.grey600))
            else ...[
              pw.TableHelper.fromTextArray(
                headers: ['Nome', 'Valor', 'Status'],
                data: [
                  for (final r in b.totals!.items)
                    [
                      r.nome,
                      currency(r.valor),
                      r.isPago ? 'Pago' : 'Pendente',
                    ],
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Recebido: ${currency(b.totals!.pago)}  '),
                  pw.Text('Pendente: ${currency(b.totals!.pendente)}'),
                ],
              ),
            ],
            for (final s in b.attendance) ...[
              pw.SizedBox(height: 8),
              pw.Text(
                'PRESENÇA — ${DateFormat('dd/MM/yyyy').format(DateTime.parse(s.data))} — ${s.presentes} presente(s) / ${s.pessoas.length}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
              pw.Text(
                s.pessoas.where((p) => p.presente).map((p) => p.nome).join(', '),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
            pw.SizedBox(height: 18),
          ],
      ],
    ),
  );
  return doc;
}

class _Block {
  _Block({
    required this.grupo,
    required this.edition,
    required this.totals,
    required this.finances,
    required this.attendance,
  });

  final String grupo;
  final Edition? edition;
  final EditionTotals? totals;
  final List<FinanceEntry> finances;
  final List<AttendanceSession> attendance;
}
