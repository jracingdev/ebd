import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/utils/format.dart';

String financeReceiptFilename(FinanceEntry entry) =>
    'recibo-${entry.tipo}-${entry.id}.pdf';

Future<Uint8List> buildFinanceReceiptPdf(
  FinanceEntry entry, {
  String igreja = 'Escola Bíblica Dominical',
  PdfPageFormat format = PdfPageFormat.a5,
}) async {
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
  final tipo = entry.tipo == 'oferta' ? 'Oferta' : 'Doação';
  doc.addPage(
    pw.Page(
      pageFormat: format,
      theme: theme,
      build: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.all(24),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              igreja.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: PdfColor.fromInt(0xFFB8892B),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Recibo de $tipo',
              style: pw.TextStyle(
                fontSize: 20,
                fontStyle: pw.FontStyle.italic,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Emitido em ${formatDate(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Divider(thickness: 1.5),
            pw.SizedBox(height: 12),
            _row('Turma', entry.grupo),
            _row('Data', entry.data),
            _row('Tipo', tipo),
            _row('Valor', currency(entry.valor)),
            if (entry.descricao.isNotEmpty) _row('Obs.', entry.descricao),
            pw.SizedBox(height: 24),
            pw.Text(
              'Agradecemos a contribuição. Que o Senhor multiplique.',
              style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
            ),
            pw.Spacer(),
            pw.Text(
              'Recibo nº ${entry.id}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
            ),
          ],
        ),
      ),
    ),
  );
  return doc.save();
}

/// Compartilha o PDF diretamente (sem preview). Preferir [previewFinanceReceipt].
Future<void> shareFinanceReceipt(
  FinanceEntry entry, {
  String igreja = 'Escola Bíblica Dominical',
}) async {
  final bytes = await buildFinanceReceiptPdf(entry, igreja: igreja);
  await Printing.sharePdf(
    bytes: bytes,
    filename: financeReceiptFilename(entry),
  );
}

pw.Widget _row(String k, String v) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 72,
            child: pw.Text(
              k,
              style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 11),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              v,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
