import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/config/app_config.dart';
import '../../core/services/anthropic_service.dart';
import '../../core/services/chunking_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/markdown_normalizer.dart';
import '../../core/services/pdf_service.dart';
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
    String? defaultModel,
  })  : _db = database,
        _pdfService = pdfService,
        _chunkingService = chunkingService,
        _normalizer = markdownNormalizer ?? MarkdownNormalizer(),
        _anthropicService = anthropicService,
        _defaultModel = defaultModel;

  final Database _db;
  final PdfService _pdfService;
  final ChunkingService _chunkingService;
  final MarkdownNormalizer _normalizer;
  final AnthropicService? _anthropicService;
  final String? _defaultModel;

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
  Future<String?> _generateDescription(List<TextChunk> chunks) async {
    if (_anthropicService == null) return null;
    if (chunks.isEmpty) return null;

    try {
      // Usa primeiros 3 chunks como amostra
      final sample = chunks.take(3).map((c) => c.content).join('\n\n');
      final prompt = 'Resuma o documento abaixo em uma a duas frases curtas em português. '
          'Retorne APENAS o resumo, sem prefixo nem explicação.\n\n$sample';

      final responseBuffer = StringBuffer();
      await for (final token in _anthropicService!.sendMessage(
        userMessage: prompt,
        context: '',
        history: [],
        model: _defaultModel ?? AppConfig.defaultModel,
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

  /// Deleta documento e seus chunks (cascade manual).
  Future<void> deleteDocument(int documentId) async {
    await _db.delete('chunks', where: 'document_id = ?', whereArgs: [documentId]);
    await _db.delete('documents', where: 'id = ?', whereArgs: [documentId]);
  }
}
