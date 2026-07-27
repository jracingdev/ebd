import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:livro_registro/theme/app_theme.dart';
import 'package:livro_registro/widgets/common.dart';

/// Tela genérica de preview de PDF (recibo, relatório, etc.).
/// O usuário visualiza e decide compartilhar, salvar/imprimir ou fechar.
class PdfDocumentPreviewScreen extends StatelessWidget {
  const PdfDocumentPreviewScreen({
    super.key,
    required this.title,
    required this.filename,
    required this.buildPdf,
    this.initialPageFormat = PdfPageFormat.a4,
  });

  final String title;
  final String filename;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;
  final PdfPageFormat initialPageFormat;

  Future<void> _share() async {
    final bytes = await buildPdf(initialPageFormat);
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }

  Future<void> _print() async {
    await Printing.layoutPdf(
      onLayout: buildPdf,
      name: filename,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: SecondaryAppBar(
        title: title,
        actions: [
          IconButton(
            tooltip: 'Compartilhar',
            icon: const Icon(Icons.share_outlined),
            onPressed: _share,
          ),
          IconButton(
            tooltip: 'Salvar / imprimir',
            icon: const Icon(Icons.print_outlined),
            onPressed: _print,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              build: buildPdf,
              initialPageFormat: initialPageFormat,
              allowPrinting: false,
              allowSharing: false,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              pdfFileName: filename,
              actions: const [],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Fechar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _print,
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text('Salvar'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Compartilhar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openPdfDocumentPreview(
  BuildContext context, {
  required String title,
  required String filename,
  required Future<Uint8List> Function(PdfPageFormat format) buildPdf,
  PdfPageFormat initialPageFormat = PdfPageFormat.a4,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PdfDocumentPreviewScreen(
        title: title,
        filename: filename,
        buildPdf: buildPdf,
        initialPageFormat: initialPageFormat,
      ),
    ),
  );
}
