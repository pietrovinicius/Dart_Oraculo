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

    var rows = await _executeSearch(sanitized, collectionId, effectiveLimit);

    // Fallback cascata:
    // 1. Se AND retorna vazio e há múltiplos termos → OR
    if (rows.isEmpty && sanitized.contains(' ')) {
      final orQuery = sanitized
          .split(' ')
          .where((t) => t.isNotEmpty)
          .join(' OR ');
      LoggerService.instance.info(_tag,
          'AND retornou 0 → fallback OR: "$orQuery"');
      rows = await _executeSearch(orQuery, collectionId, effectiveLimit);
    }

    // 2. Se ainda vazio → prefix match no primeiro termo
    if (rows.isEmpty) {
      final firstTerm = sanitized
          .replaceAll('"', '')
          .split(' ')
          .firstWhere((t) => t.isNotEmpty, orElse: () => '');
      if (firstTerm.isNotEmpty) {
        final prefixQuery = '$firstTerm*';
        LoggerService.instance.info(_tag,
            'OR retornou 0 → fallback prefix: "$prefixQuery"');
        rows = await _executeSearch(prefixQuery, collectionId, effectiveLimit);
      }
    }

    return rows.map((row) => FtsResult(
      chunkId: row['chunk_id'] as int,
      documentId: row['document_id'] as int,
      filename: row['filename'] as String,
      page: row['page'] as int?,
      content: row['content'] as String,
      rank: (row['rank'] as num).toDouble(),
    )).toList();
  }

  /// Executa query FTS5 raw com filtro de coleção.
  Future<List<Map<String, Object?>>> _executeSearch(
    String matchQuery,
    int? collectionId,
    int limit,
  ) async {
    final whereClause = collectionId != null
        ? 'WHERE chunks_fts MATCH ? AND d.collection_id = ?'
        : 'WHERE chunks_fts MATCH ?';
    final args = collectionId != null
        ? [matchQuery, collectionId, limit]
        : [matchQuery, limit];

    return _db.rawQuery('''
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
  }

  // Stopwords pt-BR + en — removidas da query FTS5
  static const _stopwords = <String>{
    // Português — artigos, preposições, pronomes
    'a', 'o', 'e', 'é', 'de', 'do', 'da', 'dos', 'das',
    'em', 'no', 'na', 'nos', 'nas', 'um', 'uma', 'uns', 'umas',
    'por', 'para', 'com', 'sem', 'que', 'se', 'ou', 'mas',
    'como', 'esse', 'essa', 'este', 'esta', 'isso', 'isto',
    'ele', 'ela', 'eles', 'elas', 'eu', 'tu', 'nós', 'vos',
    'me', 'te', 'lhe', 'ao', 'aos', 'as', 'os',
    'voce', 'você', 'meu', 'sua', 'seu', 'não', 'nao',
    'ser', 'ter', 'há', 'ha', 'foi', 'são', 'sao',
    // Português — verbos/palavras comuns em perguntas
    'tem', 'pode', 'sabe', 'sabre', 'faz', 'fazer',
    'sobre', 'cima', 'dessa', 'nessa', 'desse', 'nesse',
    'existe', 'existir', 'qual', 'quais', 'onde', 'quando',
    'algum', 'alguma', 'alguns', 'algumas',
    'mais', 'muito', 'tambem', 'também', 'ainda', 'já', 'ja',
    'aqui', 'ali', 'lá', 'la', 'sim', 'favor',
    // Inglês
    'the', 'an', 'is', 'are', 'was', 'were', 'be',
    'of', 'and', 'or', 'in', 'on', 'at', 'to', 'for',
    'it', 'this', 'that', 'with', 'from', 'by',
  };

  bool _isStopword(String word) => _stopwords.contains(word.toLowerCase());

  /// Termo técnico: contém underscore OU é ALLCAPS (≥3 chars).
  bool _isTechnicalTerm(String word) {
    if (word.contains('_')) return true;
    if (word.length >= 3 && word == word.toUpperCase() &&
        word.contains(RegExp(r'[A-Z]'))) return true;
    return false;
  }

  /// Extrai linguagem natural de uma query, ignorando blocos de código/SQL.
  /// Heurística: linhas que começam com keyword SQL são descartadas.
  static final _sqlLinePattern = RegExp(
    r'^\s*(SELECT|FROM|WHERE|AND|OR|INSERT|UPDATE|DELETE|JOIN|LEFT|RIGHT|'
    r'GROUP|ORDER|HAVING|UNION|CREATE|ALTER|DROP|SET|INTO|VALUES|LIMIT|'
    r'OFFSET|CASE|WHEN|THEN|ELSE|END|AS|ON|IN|NOT|LIKE|BETWEEN|EXISTS|'
    r'IS|NULL|DISTINCT|COUNT|SUM|AVG|MAX|MIN|OVER|PARTITION|WITH)\b',
    caseSensitive: false,
  );

  String _extractNaturalLanguage(String query) {
    final lines = query.split('\n');
    if (lines.length <= 1) return query; // single line → usa tudo

    final natural = lines
        .where((l) => l.trim().isNotEmpty && !_sqlLinePattern.hasMatch(l))
        .toList();

    // Se nenhuma linha natural, fallback para query completa
    if (natural.isEmpty) return query;
    return natural.join(' ');
  }

  /// Sanitiza query para FTS5 priorizando termos técnicos:
  /// 1. Extrai linguagem natural (ignora SQL/code)
  /// 2. Remove stopwords
  /// 3. Se há termos técnicos (ALLCAPS/underscore) → usa só eles
  /// 4. Termos com underscore viram phrase match
  /// 5. Limita a 8 termos para evitar queries explosivas
  String _sanitizeQuery(String query) {
    final naturalText = _extractNaturalLanguage(query);
    final cleaned = naturalText.replaceAll(RegExp(r'[^\w\s\p{L}_]', unicode: true), ' ');
    final words = cleaned.split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_isStopword(w))
        .toList();

    if (words.isEmpty) return '';

    // Separa técnicos de comuns
    final technical = words.where(_isTechnicalTerm).toList();

    // Prioriza termos técnicos se existem
    final priority = technical.isNotEmpty ? technical : words;

    // Limita a 8 termos para evitar queries FTS5 monstruosas
    final limited = priority.take(8).toList();

    return limited
        .map((w) => w.contains('_') ? '"$w"' : w)
        .join(' ');
  }
}
