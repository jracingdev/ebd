import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:livro_registro/data/models.dart';
import 'package:livro_registro/features/finances/receipt_pdf.dart';
import 'package:livro_registro/widgets/pdf_document_preview_screen.dart';

/// Abre a tela de preview; o usuário decide compartilhar, salvar/imprimir ou fechar.
Future<void> previewFinanceReceipt(
  BuildContext context,
  FinanceEntry entry, {
  String igreja = 'Escola Bíblica Dominical',
}) {
  return openPdfDocumentPreview(
    context,
    title: entry.tipo == 'oferta' ? 'Comprovante — Oferta' : 'Comprovante — Doação',
    filename: financeReceiptFilename(entry),
    initialPageFormat: PdfPageFormat.a5,
    buildPdf: (format) => buildFinanceReceiptPdf(
      entry,
      igreja: igreja,
      format: PdfPageFormat.a5,
    ),
  );
}
