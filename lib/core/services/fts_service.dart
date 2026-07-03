import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/app_config.dart';

/// Resultado de busca FTS5 com metadados do chunk e documento.
class FtsResult {
  const FtsResult({
    required this.chunkId,
    required this.documentId,
    required this.filename,
    this.page,
    required this.content,
    required this.rank,
  });

  final int chunkId;
  final int documentId;
  final String filename;
  final int? page;
  final String content;
  final double rank;
}

/// Busca de texto completo via FTS5 com ranking BM25.
class FtsService {
  FtsService({required Database database}) : _db = database;

  final Database _db;

  /// Busca chunks relevantes para a [query].
  /// Retorna até [limit] resultados ordenados por relevância BM25.
  Future<List<FtsResult>> search(
    String query, {
    int? limit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final effectiveLimit = limit ?? AppConfig.maxChunksPerQuery;

    // Sanitiza a query para FTS5: remove caracteres especiais que
    // poderiam quebrar a sintaxe FTS5
    final sanitized = _sanitizeQuery(trimmed);
    if (sanitized.isEmpty) return [];

    final rows = await _db.rawQuery('''
      SELECT
        c.id AS chunk_id,
        c.document_id,
        d.filename,
        c.page,
        c.content,
        rank
      FROM chunks_fts
      JOIN chunks c ON c.id = chunks_fts.rowid
      JOIN documents d ON d.id = c.document_id
      WHERE chunks_fts MATCH ?
      ORDER BY rank
      LIMIT ?
    ''', [sanitized, effectiveLimit]);

    return rows.map((row) => FtsResult(
      chunkId: row['chunk_id'] as int,
      documentId: row['document_id'] as int,
      filename: row['filename'] as String,
      page: row['page'] as int?,
      content: row['content'] as String,
      rank: (row['rank'] as num).toDouble(),
    )).toList();
  }

  /// Sanitiza query removendo operadores FTS5 que poderiam causar erro.
  /// Mantém apenas palavras alfanuméricas separadas por OR implícito.
  String _sanitizeQuery(String query) {
    // Remove caracteres especiais do FTS5
    final cleaned = query.replaceAll(RegExp(r'[^\w\s\p{L}]', unicode: true), ' ');
    final words = cleaned.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    if (words.isEmpty) return '';

    // FTS5: termos separados por espaço = AND implícito
    // Usar OR para matches parciais mais flexíveis
    return words.join(' OR ');
  }
}
