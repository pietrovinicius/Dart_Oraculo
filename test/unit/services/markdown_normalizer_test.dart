import 'package:dart_oraculo/core/services/markdown_normalizer.dart';
import 'package:dart_oraculo/core/services/pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MarkdownNormalizer normalizer;

  setUp(() {
    normalizer = MarkdownNormalizer();
  });

  group('MarkdownNormalizer', () {
    test('detecta título de capítulo (dígito colado a maiúscula)', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 1,
          text: '1Recuperando Dados com a Instrução SQL SELECT\n'
              'Objetivos   1-2\n'
              'Este é um parágrafo normal de conteúdo.',
        ),
      ];

      final result = normalizer.normalize(pages);

      expect(result, contains('## 1. Recuperando Dados com a Instrução SQL SELECT'));
    });

    test('detecta título ALL CAPS em linha isolada', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 1,
          text: 'PREFÁCIO\n\nEste capítulo introduz os conceitos básicos.',
        ),
      ];

      final result = normalizer.normalize(pages);

      expect(result, contains('## PREFÁCIO'));
    });

    test('detecta padrão numérico com ponto', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 1,
          text: '1.1 Conceitos Iniciais\n\nTexto do parágrafo.',
        ),
      ];

      final result = normalizer.normalize(pages);

      expect(result, contains('## 1.1 Conceitos Iniciais'));
    });

    test('preserva parágrafos normais sem modificação', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 1,
          text: 'Este é um parágrafo normal que não deve ser tratado como título. '
              'Ele contém pontuação no final e é longo o suficiente.',
        ),
      ];

      final result = normalizer.normalize(pages);

      expect(result, contains('Este é um parágrafo normal'));
      expect(result, isNot(contains('## Este é um parágrafo')));
    });

    test('remove watermark Oracle University', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 1,
          text: 'Conteúdo real.\n'
              'Oracle University and Impacta Tecnologia use only'
              'ฺDevelopment Program (WDP) eKit materials are provided for '
              'WDP in-class use only.',
        ),
      ];

      final result = normalizer.normalize(pages);

      expect(result, contains('Conteúdo real.'));
      expect(result, isNot(contains('Oracle University')));
    });

    test('marca quebra de página entre páginas', () {
      final pages = [
        const PdfPageResult(pageNumber: 1, text: 'Conteúdo página 1.'),
        const PdfPageResult(pageNumber: 2, text: 'Conteúdo página 2.'),
      ];

      final result = normalizer.normalize(pages);

      expect(result, contains('---'));
      expect(result, contains('<!-- p.2 -->'));
    });

    test('trata linhas de sumário como lista', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 3,
          text: 'Objetivos da Lição   I-2\n'
              'Metas do Curso   I-3\n'
              'Oracle10g   I-4',
        ),
      ];

      final result = normalizer.normalize(pages);

      expect(result, contains('- Objetivos da Lição (I-2)'));
      expect(result, contains('- Metas do Curso (I-3)'));
    });

    test('retorna string vazia para páginas sem conteúdo útil', () {
      final pages = [
        const PdfPageResult(pageNumber: 1, text: '   \n  \n '),
      ];

      final result = normalizer.normalize(pages);

      expect(result.trim(), isEmpty);
    });

    test('múltiplos padrões na mesma página', () {
      final pages = [
        const PdfPageResult(
          pageNumber: 5,
          text: '3Usando Functions de uma Única Linha para Personalizar a Saída\n'
              'Objetivos   3-2\n'
              'Functions SQL   3-3\n\n'
              'Existem dois tipos de functions SQL que você pode usar.',
        ),
      ];

      final result = normalizer.normalize(pages);

      expect(result, contains('## 3. Usando Functions de uma Única Linha'));
      expect(result, contains('- Objetivos (3-2)'));
      expect(result, contains('Existem dois tipos de functions SQL'));
    });
  });
}
