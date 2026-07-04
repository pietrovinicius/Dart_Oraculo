import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/services/anthropic_service.dart';
import '../../core/services/chunking_service.dart';
import '../../core/services/generation_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/markdown_normalizer.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/structured_data_chunker.dart';
import 'models/chunk.dart';
import 'models/document.dart';

/// Serviço de ingestão de documentos.
/// Orquestra: extração → normalização markdown → chunking → persistência.
/// Suporta PDF e Markdown como formatos de entrada.
class DocumentService {
  DocumentService({
    required Database database,
    required PdfService pdfService,
    required ChunkingService chunkingService,
    MarkdownNormalizer? markdownNormalizer,
    AnthropicService? anthropicService,
    GenerationService? generationService,
    String? defaultModel,
  })  : _db = database,
        _pdfService = pdfService,
        _chunkingService = chunkingService,
        _normalizer = markdownNormalizer ?? MarkdownNormalizer(),
        _anthropicService = anthropicService,
        _generationService = generationService;

  final Database _db;
  final PdfService _pdfService;
  final ChunkingService _chunkingService;
  final MarkdownNormalizer _normalizer;
  final AnthropicService? _anthropicService;
  final GenerationService? _generationService;

  static const _tag = 'DocumentService';

  /// Ingere um PDF: extrai texto → normaliza para markdown → fragmenta → persiste.
  /// [onProgress] recebe fração 0.0..1.0 representando progresso da extração.
  Future<Document> ingestPdf({
    required Uint8List bytes,
    required String filename,
    String? sourcePath,
    int? collectionId,
    void Function(double progress)? onProgress,
  }) async {
    LoggerService.instance.info(_tag, 'ingestPdf("$filename", ${bytes.length} bytes)');
    final pages = await _pdfService.extractText(
      bytes,
      onProgress: onProgress != null
          ? (current, total) => onProgress(current / total)
          : null,
    );
    LoggerService.instance.info(_tag, 'PDF extraído: ${pages.length} páginas');

    final markdown = _normalizer.normalize(pages);
    LoggerService.instance.info(_tag, 'Normalizado para markdown: ${markdown.length} chars');

    final markdownPages = [
      PdfPageResult(pageNumber: 1, text: markdown),
    ];
    final textChunks = _chunkingService.chunkPages(markdownPages);
    LoggerService.instance.info(_tag, 'Chunking: ${textChunks.length} chunks gerados');

    return _persistDocument(
      filename: filename,
      sourcePath: sourcePath,
      collectionId: collectionId,
      chunks: textChunks,
    );
  }

  /// Ingere um arquivo Markdown: conteúdo já no formato final → chunking direto.
  /// [onProgress] chamado com 1.0 imediatamente (leitura instantânea).
  Future<Document> ingestMarkdown({
    required Uint8List bytes,
    required String filename,
    String? sourcePath,
    int? collectionId,
    void Function(double progress)? onProgress,
  }) async {
    LoggerService.instance.info(_tag, 'ingestMarkdown("$filename", ${bytes.length} bytes)');
    final content = utf8.decode(bytes);
    onProgress?.call(1.0);

    // Markdown já está no formato final — chunking direto com page null
    final textChunks = _chunkingService.chunkPages([
      PdfPageResult(pageNumber: 0, text: content),
    ]);

    // Usar page null para chunks de markdown (arquivo inteiro)
    final chunksWithNullPage = textChunks
        .map((c) => TextChunk(page: 0, content: c.content))
        .toList();

    return _persistDocument(
      filename: filename,
      sourcePath: sourcePath,
      collectionId: collectionId,
      chunks: chunksWithNullPage,
      useNullPage: true,
    );
  }

  /// Persiste documento e chunks no banco, depois gera descrição via AI.
  Future<Document> _persistDocument({
    required String filename,
    String? sourcePath,
    required List<TextChunk> chunks,
    bool useNullPage = false,
    int? collectionId,
  }) async {
    final now = DateTime.now();

    final docId = await _db.insert('documents', {
      'filename': filename,
      'source_path': sourcePath,
      'collection_id': collectionId,
      'imported_at': now.toIso8601String(),
    });

    for (final chunk in chunks) {
      await _db.insert('chunks', {
        'document_id': docId,
        'page': useNullPage ? null : chunk.page,
        'content': chunk.content,
        'created_at': now.toIso8601String(),
      });
    }

    // Gera descrição usando primeiros chunks como contexto
    final description = await _generateDescription(chunks);
    if (description != null) {
      await _db.update(
        'documents',
        {'description': description},
        where: 'id = ?',
        whereArgs: [docId],
      );
    }

    return Document(
      id: docId,
      filename: filename,
      sourcePath: sourcePath,
      importedAt: now,
      collectionId: collectionId,
      description: description,
    );
  }

  /// Gera descrição de 1-2 frases usando os primeiros chunks como entrada.
  /// Usa o GenerationService ativo (pode ser Anthropic ou Ollama).
  Future<String?> _generateDescription(List<TextChunk> chunks) async {
    // Resolve qual service usar: _generationService (preferido) ou _anthropicService (fallback)
    final service = _generationService ?? _anthropicService;
    if (service == null) return null;
    if (chunks.isEmpty) return null;

    try {
      // Usa primeiros 3 chunks como amostra
      final sample = chunks.take(3).map((c) => c.content).join('\n\n');
      final prompt = 'Resuma o documento abaixo em uma a duas frases curtas em português. '
          'Retorne APENAS o resumo, sem prefixo nem explicação.\n\n$sample';

      final responseBuffer = StringBuffer();
      await for (final token in service.streamResponse(
        systemPrompt: 'Você é um assistente que gera resumos concisos.',
        history: [],
        question: prompt,
      )) {
        responseBuffer.write(token);
      }

      final desc = responseBuffer.toString().trim();
      LoggerService.instance.info(_tag, 'Descrição gerada: ${desc.length} chars');
      return desc.isNotEmpty ? desc : null;
    } catch (e) {
      LoggerService.instance.warn(_tag, 'Falha ao gerar descrição: $e');
      return null;
    }
  }

  /// Lista todos os documentos importados.
  Future<List<Document>> listDocuments() async {
    final rows = await _db.query('documents', orderBy: 'imported_at DESC');
    return rows.map(Document.fromMap).toList();
  }

  /// Retorna chunks de um documento específico.
  Future<List<Chunk>> getChunksForDocument(int documentId) async {
    final rows = await _db.query(
      'chunks',
      where: 'document_id = ?',
      whereArgs: [documentId],
      orderBy: 'id ASC',
    );
    return rows.map(Chunk.fromMap).toList();
  }

  /// Exporta documento como markdown concatenando chunks na ordem original.
  /// [outputDir] é opcional — usa Application Support/exports por padrão.
  ///
  /// Cache por identidade: se o arquivo já existe para este documentId, retorna
  /// o caminho existente sem reprocessar. Premissa: documentos não são editados
  /// pós-ingestão. Se edição de documento for adicionada no futuro, a
  /// invalidação de cache precisará ser revisada (comparar hash ou deletar
  /// arquivo no momento da edição).
  Future<String> exportAsMarkdown(int documentId, {Directory? outputDir}) async {
    final doc = await _db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [documentId],
    );
    if (doc.isEmpty) throw Exception('Documento não encontrado');

    final filename = doc.first['filename'] as String;

    final Directory exportDir;
    if (outputDir != null) {
      exportDir = outputDir;
    } else {
      final appDir = await getApplicationSupportDirectory();
      exportDir = Directory('${appDir.path}/exports');
    }
    if (!exportDir.existsSync()) {
      exportDir.createSync(recursive: true);
    }

    final baseName = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
    final exportPath = '${exportDir.path}/$baseName.md';

    // Cache: se já existe, retorna sem reprocessar
    if (File(exportPath).existsSync()) {
      LoggerService.instance.info(_tag, 'Export cache hit: $exportPath');
      return exportPath;
    }

    final chunks = await getChunksForDocument(documentId);
    final content = chunks.map((c) => c.content).join('\n\n');
    await File(exportPath).writeAsString(content);

    LoggerService.instance.info(_tag, 'Exportado: $exportPath (${content.length} chars)');
    return exportPath;
  }

  /// Ingere arquivo CSV ou JSON com chunking por agrupamento de identidade.
  /// Parsing roda em Isolate para não bloquear UI.
  /// Inserções em batch via transaction para performance.
  /// Progresso granular por grupo processado.
  Future<Document> ingestStructuredData({
    required Uint8List bytes,
    required String filename,
    required String groupByColumn,
    String? sourcePath,
    int? collectionId,
    void Function(double progress)? onProgress,
  }) async {
    LoggerService.instance.info(
      _tag,
      'ingestStructuredData("$filename", groupBy=$groupByColumn)',
    );

    // 1. Parsing em Isolate (não bloqueia UI)
    onProgress?.call(0.0);
    final content = utf8.decode(bytes);
    final List<Map<String, dynamic>> rows;

    if (filename.endsWith('.csv')) {
      rows = _parseCsv(content);
    } else if (filename.endsWith('.json')) {
      rows = await _parseJsonInIsolate(content);
    } else {
      throw ArgumentError('Formato não suportado: $filename (use .csv ou .json)');
    }

    LoggerService.instance.info(_tag, 'Parsed ${rows.length} linhas');
    onProgress?.call(0.3);

    // 2. Chunking
    final chunker = StructuredDataChunker();
    final textChunks = chunker.chunkByGroup(
      rows: rows,
      groupByColumn: groupByColumn,
    );

    LoggerService.instance.info(_tag, 'Chunking: ${textChunks.length} grupos');
    onProgress?.call(0.5);

    // 3. Persistência com batch inserts + progresso granular
    return _persistDocumentBatch(
      filename: filename,
      sourcePath: sourcePath,
      collectionId: collectionId,
      chunks: textChunks,
      onProgress: (batchProgress) {
        // Progresso de 0.5 a 1.0 durante persistência
        onProgress?.call(0.5 + batchProgress * 0.5);
      },
    );
  }

  /// Parseia JSON em Isolate para não bloquear a thread principal.
  Future<List<Map<String, dynamic>>> _parseJsonInIsolate(String content) async {
    // Para arquivos menores (< 5MB), parseia inline sem overhead de Isolate
    if (content.length < 5 * 1024 * 1024) {
      return _parseJson(content);
    }
    // Para arquivos grandes, usa compute() em Isolate separado
    return await compute(_parseJsonStatic, content);
  }

  /// Função estática para rodar em Isolate (não pode acessar `this`).
  static List<Map<String, dynamic>> _parseJsonStatic(String content) {
    final decoded = jsonDecode(content);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw const FormatException('JSON deve ser um array de objetos');
  }

  /// Persiste documento e chunks em batch via transaction.
  /// Progresso granular por lote de 1000 chunks.
  Future<Document> _persistDocumentBatch({
    required String filename,
    String? sourcePath,
    int? collectionId,
    required List<TextChunk> chunks,
    void Function(double progress)? onProgress,
  }) async {
    final now = DateTime.now();

    final docId = await _db.insert('documents', {
      'filename': filename,
      'source_path': sourcePath,
      'collection_id': collectionId,
      'imported_at': now.toIso8601String(),
    });

    final totalChunks = chunks.length;
    const batchSize = 1000;

    for (var i = 0; i < totalChunks; i += batchSize) {
      final end = (i + batchSize < totalChunks) ? i + batchSize : totalChunks;
      final batch = chunks.sublist(i, end);

      await _db.transaction((txn) async {
        for (final chunk in batch) {
          await txn.insert('chunks', {
            'document_id': docId,
            'page': null,
            'content': chunk.content,
            'created_at': now.toIso8601String(),
          });
        }
      });

      onProgress?.call(end / totalChunks);

      // Yield ao framework para atualizar UI entre batches
      await Future<void>.delayed(Duration.zero);
    }

    // Gera descrição
    final description = await _generateDescription(chunks);
    if (description != null) {
      await _db.update(
        'documents',
        {'description': description},
        where: 'id = ?',
        whereArgs: [docId],
      );
    }

    LoggerService.instance.info(
      _tag,
      'Persistido: $totalChunks chunks em batches de $batchSize',
    );

    return Document(
      id: docId,
      filename: filename,
      sourcePath: sourcePath,
      importedAt: now,
      collectionId: collectionId,
      description: description,
    );
  }

  /// Parseia CSV para lista de mapas (header como chave).
  List<Map<String, dynamic>> _parseCsv(String content) {
    final parsed = const CsvToListConverter(eol: '\n').convert(content);
    if (parsed.length < 2) return [];

    final headers = parsed.first.map((h) => h.toString()).toList();
    return parsed.skip(1).map((row) {
      final map = <String, dynamic>{};
      for (var i = 0; i < headers.length && i < row.length; i++) {
        map[headers[i]] = row[i];
      }
      return map;
    }).toList();
  }

  /// Parseia JSON array para lista de mapas.
  List<Map<String, dynamic>> _parseJson(String content) {
    final decoded = jsonDecode(content);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw const FormatException('JSON deve ser um array de objetos');
  }

  /// Deleta documento e seus chunks (cascade manual).
  Future<void> deleteDocument(int documentId) async {
    await _db.delete('chunks', where: 'document_id = ?', whereArgs: [documentId]);
    await _db.delete('documents', where: 'id = ?', whereArgs: [documentId]);
  }
}
