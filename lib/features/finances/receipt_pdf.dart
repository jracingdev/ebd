import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/utils/format.dart';

Future<void> shareFinanceReceipt(
  FinanceEntry entry, {
  String igreja = 'Escola Bíblica Dominical',
}) async {
  final doc = pw.Document();
  final tipo = entry.tipo == 'oferta' ? 'Oferta' : 'Doação';
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
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

  final bytes = await doc.save();
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'recibo-${entry.tipo}-${entry.id}.pdf',
  );
}

pw.Widget _row(String k, String v) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(k, style: const pw.TextStyle(color: PdfColors.grey700)),
          pw.Text(v, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
