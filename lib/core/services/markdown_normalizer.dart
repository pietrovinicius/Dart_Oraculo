import 'pdf_service.dart';

/// Normaliza texto extraído de PDF para markdown estruturado.
/// Heurísticas calibradas para materiais didáticos/técnicos.
class MarkdownNormalizer {
  /// Padrão: dígito(s) colado(s) a letra maiúscula — título de capítulo.
  /// Ex: "3Usando Functions" → "## 3. Usando Functions"
  static final _chapterTitlePattern = RegExp(r'^(\d+)([A-ZÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇ].+)$');

  /// Padrão numérico com ponto no início — título de seção.
  /// Ex: "1.1 Conceitos" → "## 1.1 Conceitos"
  static final _numberedSectionPattern = RegExp(r'^(\d+\.\d*\.?\s+)(.+)$');

  /// Linha de sumário: texto seguido de espaços e referência N-N.
  /// Ex: "Objetivos   1-2" → "- Objetivos (1-2)"
  static final _tocPattern = RegExp(r'^(.+?)\s{2,}([A-Z]?\d*-\d+)$');

  /// Watermark Oracle University.
  static final _watermarkPattern = RegExp(
    r'Oracle University and Impacta Tecnologia.*$',
    multiLine: true,
    dotAll: true,
  );

  /// Linha ALL CAPS curta (< 80 chars), sem pontuação final.
  static final _allCapsPattern = RegExp(r'^[A-ZÁÀÂÃÉÈÊÍÏÓÔÕÖÚÇ\s]{3,80}$');

  /// Normaliza lista de páginas extraídas em markdown.
  String normalize(List<PdfPageResult> pages) {
    final buffer = StringBuffer();

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];

      // Quebra de página (exceto na primeira)
      if (i > 0) {
        buffer.writeln();
        buffer.writeln('---');
        buffer.writeln('<!-- p.${page.pageNumber} -->');
        buffer.writeln();
      }

      final cleaned = _removeWatermark(page.text);
      final lines = cleaned.split('\n');

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          buffer.writeln();
          continue;
        }

        final normalized = _normalizeLine(trimmed);
        buffer.writeln(normalized);
      }
    }

    return buffer.toString();
  }

  String _removeWatermark(String text) {
    return text.replaceAll(_watermarkPattern, '').trim();
  }

  String _normalizeLine(String line) {
    // 1. Título de capítulo: dígito colado a maiúscula
    final chapterMatch = _chapterTitlePattern.firstMatch(line);
    if (chapterMatch != null) {
      final num = chapterMatch.group(1);
      final title = chapterMatch.group(2);
      return '## $num. $title';
    }

    // 2. Seção numerada: "1.1 Texto"
    final sectionMatch = _numberedSectionPattern.firstMatch(line);
    if (sectionMatch != null) {
      final prefix = sectionMatch.group(1)!.trim();
      final title = sectionMatch.group(2);
      return '## $prefix $title';
    }

    // 3. Linha de sumário: "Texto   N-N"
    final tocMatch = _tocPattern.firstMatch(line);
    if (tocMatch != null) {
      final title = tocMatch.group(1)!.trim();
      final ref = tocMatch.group(2);
      return '- $title ($ref)';
    }

    // 4. ALL CAPS curta sem pontuação final
    if (_allCapsPattern.hasMatch(line) && !_endsWithPunctuation(line)) {
      return '## $line';
    }

    // 5. Parágrafo normal
    return line;
  }

  bool _endsWithPunctuation(String text) {
    if (text.isEmpty) return false;
    final last = text[text.length - 1];
    return '.!?:;,'.contains(last);
  }
}
