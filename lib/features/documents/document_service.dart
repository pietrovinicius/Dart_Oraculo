import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/services/chunking_service.dart';
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
  })  : _db = database,
        _pdfService = pdfService,
        _chunkingService = chunkingService,
        _normalizer = markdownNormalizer ?? MarkdownNormalizer();

  final Database _db;
  final PdfService _pdfService;
  final ChunkingService _chunkingService;
  final MarkdownNormalizer _normalizer;

  /// Ingere um PDF: extrai texto → normaliza para markdown → fragmenta → persiste.
  /// Retorna o [Document] criado com seu ID.
  Future<Document> ingestPdf({
    required Uint8List bytes,
    required String filename,
    String? sourcePath,
  }) async {
    final pages = await _pdfService.extractText(bytes);

    // Normaliza texto bruto para markdown estruturado
    final markdown = _normalizer.normalize(pages);

    // Chunking sobre o markdown normalizado (tratado como página única)
    final markdownPages = [
      PdfPageResult(pageNumber: 1, text: markdown),
    ];
    final textChunks = _chunkingService.chunkPages(markdownPages);

    return _persistDocument(
      filename: filename,
      sourcePath: sourcePath,
      chunks: textChunks,
    );
  }

  /// Ingere um arquivo Markdown: conteúdo já no formato final → chunking direto.
  /// Retorna o [Document] criado com seu ID.
  Future<Document> ingestMarkdown({
    required Uint8List bytes,
    required String filename,
    String? sourcePath,
  }) async {
    final content = utf8.decode(bytes);

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
      chunks: chunksWithNullPage,
      useNullPage: true,
    );
  }

  /// Persiste documento e chunks no banco.
  Future<Document> _persistDocument({
    required String filename,
    String? sourcePath,
    required List<TextChunk> chunks,
    bool useNullPage = false,
  }) async {
    final now = DateTime.now();

    final docId = await _db.insert('documents', {
      'filename': filename,
      'source_path': sourcePath,
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

    return Document(
      id: docId,
      filename: filename,
      sourcePath: sourcePath,
      importedAt: now,
    );
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
      orderBy: 'page ASC, id ASC',
    );
    return rows.map(Chunk.fromMap).toList();
  }

  /// Deleta documento e seus chunks (cascade manual).
  Future<void> deleteDocument(int documentId) async {
    await _db.delete('chunks', where: 'document_id = ?', whereArgs: [documentId]);
    await _db.delete('documents', where: 'id = ?', whereArgs: [documentId]);
  }
}
