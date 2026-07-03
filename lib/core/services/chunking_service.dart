import '../config/app_config.dart';
import 'pdf_service.dart';

/// Chunk de texto pronto para persistência.
class TextChunk {
  const TextChunk({required this.page, required this.content});

  final int page;
  final String content;
}

/// Fragmenta texto extraído de PDF em chunks de tamanho controlado.
class ChunkingService {
  ChunkingService({int? maxTokensPerChunk})
      : _maxTokensPerChunk = maxTokensPerChunk ?? AppConfig.chunkMaxTokens;

  final int _maxTokensPerChunk;

  /// Estimativa grosseira: 1 token ≈ 4 caracteres.
  int _estimateTokens(String text) => (text.length / 4).ceil();

  /// Fragmenta páginas extraídas em chunks.
  /// Quebra por parágrafo; parágrafos longos são subdivididos por sentença.
  List<TextChunk> chunkPages(List<PdfPageResult> pages) {
    final chunks = <TextChunk>[];

    for (final page in pages) {
      final paragraphs = _splitParagraphs(page.text);

      for (final paragraph in paragraphs) {
        if (_estimateTokens(paragraph) <= _maxTokensPerChunk) {
          chunks.add(TextChunk(page: page.pageNumber, content: paragraph));
        } else {
          final subChunks = _splitBySentence(paragraph);
          for (final sub in subChunks) {
            chunks.add(TextChunk(page: page.pageNumber, content: sub));
          }
        }
      }
    }

    return chunks;
  }

  /// Quebra texto em parágrafos (separados por linhas em branco).
  /// Filtra parágrafos vazios.
  List<String> _splitParagraphs(String text) {
    return text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  /// Subdivide parágrafo longo em chunks por sentença,
  /// acumulando sentenças até o limite de tokens.
  List<String> _splitBySentence(String paragraph) {
    final sentences = paragraph
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final result = <String>[];
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      final candidate = buffer.isEmpty
          ? sentence
          : '${buffer.toString()} $sentence';

      if (_estimateTokens(candidate) > _maxTokensPerChunk &&
          buffer.isNotEmpty) {
        result.add(buffer.toString().trim());
        buffer.clear();
        buffer.write(sentence);
      } else {
        if (buffer.isNotEmpty) buffer.write(' ');
        buffer.write(sentence);
      }
    }

    if (buffer.isNotEmpty) {
      result.add(buffer.toString().trim());
    }

    return result.where((s) => s.isNotEmpty).toList();
  }
}
