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
  /// Retorna lista de [PdfPageResult] com número da página e texto.
  /// Lança exceção se os bytes não forem um PDF válido.
  Future<List<PdfPageResult>> extractText(Uint8List bytes) async {
    final document = PdfDocument(inputBytes: bytes);
    final results = <PdfPageResult>[];

    try {
      for (var i = 0; i < document.pages.count; i++) {
        final extractor = PdfTextExtractor(document);
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        results.add(PdfPageResult(pageNumber: i + 1, text: text));
      }
    } finally {
      document.dispose();
    }

    return results;
  }
}
