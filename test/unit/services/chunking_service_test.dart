import 'package:dart_oraculo/core/services/chunking_service.dart';
import 'package:dart_oraculo/core/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ChunkingService chunkingService;

  setUp(() {
    chunkingService = ChunkingService(maxTokensPerChunk: 50);
  });

  group('ChunkingService', () {
    test('fragmenta texto por parágrafos', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 1,
          text: 'Primeiro parágrafo com conteúdo.\n\n'
              'Segundo parágrafo diferente.\n\n'
              'Terceiro parágrafo final.',
        ),
      ];

      final chunks = chunkingService.chunkPages(pages);

      expect(chunks, hasLength(3));
      expect(chunks[0].content, equals('Primeiro parágrafo com conteúdo.'));
      expect(chunks[1].content, equals('Segundo parágrafo diferente.'));
      expect(chunks[2].content, equals('Terceiro parágrafo final.'));
    });

    test('preserva número da página em cada chunk', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 3,
          text: 'Parágrafo na página 3.\n\nOutro parágrafo.',
        ),
      ];

      final chunks = chunkingService.chunkPages(pages);

      expect(chunks[0].page, equals(3));
      expect(chunks[1].page, equals(3));
    });

    test('subdivide parágrafo longo por sentenças', () {
      // Com maxTokens=50 (~200 chars), um parágrafo longo deve ser subdividido
      final longParagraph = List.generate(
        10,
        (i) => 'Esta é a sentença número $i com conteúdo suficiente.',
      ).join(' ');

      final pages = [
        PdfPageResult(pageNumber: 1, text: longParagraph),
      ];

      final chunks = chunkingService.chunkPages(pages);

      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.page, equals(1));
        expect(chunk.content.isNotEmpty, isTrue);
      }
    });

    test('ignora parágrafos vazios ou só whitespace', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 1,
          text: 'Conteúdo válido.\n\n   \n\n\n\nOutro conteúdo.',
        ),
      ];

      final chunks = chunkingService.chunkPages(pages);

      expect(chunks, hasLength(2));
      expect(chunks[0].content, equals('Conteúdo válido.'));
      expect(chunks[1].content, equals('Outro conteúdo.'));
    });

    test('processa múltiplas páginas em sequência', () {
      final pages = [
        const PdfPageResult(pageNumber: 1, text: 'Página um conteúdo.'),
        const PdfPageResult(pageNumber: 2, text: 'Página dois conteúdo.'),
      ];

      final chunks = chunkingService.chunkPages(pages);

      expect(chunks, hasLength(2));
      expect(chunks[0].page, equals(1));
      expect(chunks[1].page, equals(2));
    });

    test('retorna lista vazia para páginas sem texto', () {
      final pages = [
        const PdfPageResult(pageNumber: 1, text: '   '),
        const PdfPageResult(pageNumber: 2, text: ''),
      ];

      final chunks = chunkingService.chunkPages(pages);

      expect(chunks, isEmpty);
    });
  });
}
