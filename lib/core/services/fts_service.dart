import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/app_config.dart';
import 'logger_service.dart';

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

  static const _tag = 'FTS5';
  final Database _db;

  /// Busca chunks relevantes para a [query].
  /// Filtra por [collectionId] quando fornecido (só retorna chunks de docs daquela coleção).
  /// Retorna até [limit] resultados ordenados por relevância BM25.
  Future<List<FtsResult>> search(
    String query, {
    int? limit,
    int? collectionId,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final effectiveLimit = limit ?? AppConfig.maxChunksPerQuery;

    final sanitized = _sanitizeQuery(trimmed);
    LoggerService.instance.info(_tag,
        'search() query="$trimmed" → sanitized="$sanitized" collection=$collectionId');
    if (sanitized.isEmpty) {
      LoggerService.instance.warn(_tag, 'query sanitizada vazia — retornando []');
      return [];
    }

    final whereClause = collectionId != null
        ? 'WHERE chunks_fts MATCH ? AND d.collection_id = ?'
        : 'WHERE chunks_fts MATCH ?';
    final args = collectionId != null
        ? [sanitized, collectionId, effectiveLimit]
        : [sanitized, effectiveLimit];

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
      $whereClause
      ORDER BY rank
      LIMIT ?
    ''', args);

    return rows.map((row) => FtsResult(
      chunkId: row['chunk_id'] as int,
      documentId: row['document_id'] as int,
      filename: row['filename'] as String,
      page: row['page'] as int?,
      content: row['content'] as String,
      rank: (row['rank'] as num).toDouble(),
    )).toList();
  }

  // Stopwords pt-BR + en comuns — removidas da query FTS5
  static const _stopwords = <String>{
    // Português
    'a', 'o', 'e', 'é', 'de', 'do', 'da', 'dos', 'das',
    'em', 'no', 'na', 'nos', 'nas', 'um', 'uma', 'uns', 'umas',
    'por', 'para', 'com', 'sem', 'que', 'se', 'ou', 'mas',
    'como', 'esse', 'essa', 'este', 'esta', 'isso', 'isto',
    'ele', 'ela', 'eles', 'elas', 'eu', 'tu', 'nós', 'vos',
    'me', 'te', 'lhe', 'ao', 'aos', 'as', 'os',
    'voce', 'você', 'meu', 'sua', 'seu', 'não', 'nao',
    'ser', 'ter', 'há', 'ha', 'foi', 'são', 'sao',
    // Inglês
    'the', 'an', 'is', 'are', 'was', 'were', 'be',
    'of', 'and', 'or', 'in', 'on', 'at', 'to', 'for',
    'it', 'this', 'that', 'with', 'from', 'by',
  };

  bool _isStopword(String word) => _stopwords.contains(word.toLowerCase());

  /// Sanitiza query para FTS5:
  /// 1. Preserva underscores (ADEP_V → busca exata como frase)
  /// 2. Remove stopwords pt/en
  /// 3. Usa AND implícito (FTS5 default: espaço entre termos = AND)
  /// 4. Termos com underscore viram phrase match ("ADEP_V")
  String _sanitizeQuery(String query) {
    // Remove caracteres especiais exceto underscore e letras acentuadas
    final cleaned = query.replaceAll(RegExp(r'[^\w\s\p{L}_]', unicode: true), ' ');
    final words = cleaned.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_isStopword(w))
        .toList();

    if (words.isEmpty) return '';

    // Termos com underscore → phrase match (FTS5 tokeniza underscore como separador)
    // Outros termos → AND implícito (sem operador = AND no FTS5)
    return words.map((w) => w.contains('_') ? '"$w"' : w).join(' ');
  }
}
