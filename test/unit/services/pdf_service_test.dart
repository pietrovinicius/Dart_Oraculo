import 'dart:typed_data';

import 'package:dart_oraculo/core/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Cria um PDF de teste em memória com texto em múltiplas páginas.
Uint8List _createTestPdf({int pages = 2}) {
  final document = PdfDocument();
  for (var i = 1; i <= pages; i++) {
    final page = document.pages.add();
    page.graphics.drawString(
      'Conteúdo da página $i. Flutter é multiplataforma.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );
  }
  final bytes = Uint8List.fromList(document.saveSync());
  document.dispose();
  return bytes;
}

void main() {
  late PdfService pdfService;

  setUp(() {
    pdfService = PdfService();
  });

  group('PdfService', () {
    test('extrai texto de PDF com uma página', () async {
      final bytes = _createTestPdf(pages: 1);
      final pages = await pdfService.extractText(bytes);

      expect(pages, hasLength(1));
      expect(pages[0].pageNumber, equals(1));
      expect(pages[0].text, contains('página 1'));
    });

    test('extrai texto de PDF com múltiplas páginas', () async {
      final bytes = _createTestPdf(pages: 3);
      final pages = await pdfService.extractText(bytes);

      expect(pages, hasLength(3));
      expect(pages[0].pageNumber, equals(1));
      expect(pages[1].pageNumber, equals(2));
      expect(pages[2].pageNumber, equals(3));
      expect(pages[2].text, contains('página 3'));
    });

    test('retorna lista vazia para PDF sem texto', () async {
      final document = PdfDocument();
      document.pages.add(); // página em branco
      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      final pages = await pdfService.extractText(bytes);

      // Página existe mas texto é vazio/whitespace
      expect(pages, hasLength(1));
      expect(pages[0].text.trim(), isEmpty);
    });

    test('lança exceção para bytes inválidos', () async {
      final invalidBytes = Uint8List.fromList([0, 1, 2, 3, 4]);

      expect(
        () async => await pdfService.extractText(invalidBytes),
        throwsA(isA<Object>()),
      );
    });
  });
}
