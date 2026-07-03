import 'dart:typed_data';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/services/chunking_service.dart';
import '../../core/services/pdf_service.dart';
import 'models/chunk.dart';
import 'models/document.dart';

/// Serviço de ingestão de documentos.
/// Orquestra: extração PDF → chunking → persistência no SQLite.
class DocumentService {
  DocumentService({
    required Database database,
    required PdfService pdfService,
    required ChunkingService chunkingService,
  })  : _db = database,
        _pdfService = pdfService,
        _chunkingService = chunkingService;

  final Database _db;
  final PdfService _pdfService;
  final ChunkingService _chunkingService;

  /// Ingere um PDF: extrai texto, fragmenta, persiste documento e chunks.
  /// Retorna o [Document] criado com seu ID.
  Future<Document> ingestPdf({
    required Uint8List bytes,
    required String filename,
    String? sourcePath,
  }) async {
    final pages = await _pdfService.extractText(bytes);
    final textChunks = _chunkingService.chunkPages(pages);

    final now = DateTime.now();

    final docId = await _db.insert('documents', {
      'filename': filename,
      'source_path': sourcePath,
      'imported_at': now.toIso8601String(),
    });

    for (final chunk in textChunks) {
      await _db.insert('chunks', {
        'document_id': docId,
        'page': chunk.page,
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
