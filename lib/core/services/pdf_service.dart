import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Resultado da extração de texto de uma página.
class PdfPageResult {
  const PdfPageResult({required this.pageNumber, required this.text});

  final int pageNumber;
  final String text;
}

/// Extrai texto nativo de PDFs usando syncfusion_flutter_pdf.
class PdfService {
  /// Extrai texto de cada página do PDF.
  /// [onProgress] é chamado após cada página com (paginaAtual, totalPaginas).
  Future<List<PdfPageResult>> extractText(
    Uint8List bytes, {
    void Function(int current, int total)? onProgress,
  }) async {
    final document = PdfDocument(inputBytes: bytes);
    final results = <PdfPageResult>[];

    try {
      final totalPages = document.pages.count;
      for (var i = 0; i < totalPages; i++) {
        final extractor = PdfTextExtractor(document);
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        results.add(PdfPageResult(pageNumber: i + 1, text: text));

        onProgress?.call(i + 1, totalPages);

        // Yield ao framework para atualizar UI
        if (onProgress != null) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    } finally {
      document.dispose();
    }

    return results;
  }
}
