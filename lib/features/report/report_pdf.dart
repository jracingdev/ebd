import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:livro_registro/data/app_state.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/utils/format.dart';
import 'package:livro_registro/widgets/pdf_document_preview_screen.dart';

const _reportFilename = 'relatorio-geral-ebd.pdf';

/// Abre preview do relatório; o usuário decide compartilhar, salvar ou fechar.
Future<void> previewEbdReport(BuildContext context) {
  final state = context.read<AppState>();
  return openPdfDocumentPreview(
    context,
    title: 'Relatório geral',
    filename: _reportFilename,
    initialPageFormat: PdfPageFormat.a4,
    buildPdf: (_) => buildEbdReportPdfBytes(state),
  );
}

/// Mantido por compatibilidade: agora abre o preview (não imprime direto).
Future<void> printEbdReport(BuildContext context) => previewEbdReport(context);

Future<Uint8List> buildEbdReportPdfBytes(AppState state) async {
  final doc = await buildEbdReportPdf(state);
  return doc.save();
}

Future<pw.Document> buildEbdReportPdf(AppState state) async {
  // Fontes com glyphs PT-BR (ç, ã, é, õ…) — Helvetica padrão trunca/substitui.
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final italic = await PdfGoogleFonts.notoSansItalic();
  final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();
  final theme = pw.ThemeData.withFont(
    base: base,
    bold: bold,
    italic: italic,
    boldItalic: boldItalic,
  );

  final doc = pw.Document(theme: theme);
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
      margin: const pw.EdgeInsets.fromLTRB(40, 40, 40, 48),
      theme: theme,
      build: (ctx) => [
        pw.Text(
          'ESCOLA BÍBLICA DOMINICAL',
          style: pw.TextStyle(
            fontSize: 10,
            letterSpacing: 1.2,
            color: PdfColor.fromInt(0xFFB8892B),
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Relatório geral',
          style: pw.TextStyle(
            fontSize: 22,
            fontStyle: pw.FontStyle.italic,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'Gerado em $gerado',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 16),
        if (blocks.isEmpty)
          pw.Text('Nada cadastrado ainda para gerar relatório.')
        else
          for (final b in blocks) ...[
            pw.Text(
              _groupHeading(b),
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 1),
            if (b.edition == null)
              pw.Text(
                'Sem revista cadastrada.',
                style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
              )
            else if (b.totals!.items.isEmpty)
              pw.Text(
                'Sem entregas de revista registradas.',
                style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
              )
            else ...[
              _peopleTable(b.totals!.items),
              pw.SizedBox(height: 6),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Recebido: ${currency(b.totals!.pago)}   ·   '
                  'Pendente: ${currency(b.totals!.pendente)}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (b.finances.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'Ofertas e doações',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              _financesTable(b.finances),
            ],
            for (final s in b.attendance) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                'Presença — ${DateFormat('dd/MM/yyyy').format(DateTime.parse(s.data))} — '
                '${s.presentes} presente(s) / ${s.pessoas.length}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                s.pessoas.where((p) => p.presente).map((p) => p.nome).join(', '),
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
            pw.SizedBox(height: 20),
          ],
      ],
    ),
  );
  return doc;
}

String _groupHeading(_Block b) {
  final tri = b.edition?.trimestre.trim();
  if (tri == null || tri.isEmpty) return b.grupo;
  return '${b.grupo} — $tri';
}

pw.Widget _peopleTable(List<DeliveryRecord> items) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(3.2),
      1: pw.FlexColumnWidth(1.3),
      2: pw.FlexColumnWidth(1.1),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      _headerRow(['Nome', 'Valor', 'Status']),
      for (final r in items)
        pw.TableRow(
          children: [
            _cell(r.nome),
            _cell(currency(r.valor), align: pw.TextAlign.right),
            _cell(r.isPago ? 'Pago' : 'Pendente'),
          ],
        ),
    ],
  );
}

pw.Widget _financesTable(List<FinanceEntry> items) {
  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(1.2),
      1: pw.FlexColumnWidth(1.4),
      2: pw.FlexColumnWidth(1.2),
      3: pw.FlexColumnWidth(2.2),
    },
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    children: [
      _headerRow(['Data', 'Tipo', 'Valor', 'Obs.']),
      for (final f in items)
        pw.TableRow(
          children: [
            _cell(f.data),
            _cell(f.tipo == 'oferta' ? 'Oferta' : 'Doação'),
            _cell(currency(f.valor), align: pw.TextAlign.right),
            _cell(f.descricao.isEmpty ? '—' : f.descricao),
          ],
        ),
    ],
  );
}

pw.TableRow _headerRow(List<String> labels) {
  return pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
    children: [
      for (final label in labels)
        _cell(label, bold: true),
    ],
  );
}

pw.Widget _cell(
  String text, {
  bool bold = false,
  pw.TextAlign align = pw.TextAlign.left,
}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    child: pw.Text(
      text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: 9.5,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
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
