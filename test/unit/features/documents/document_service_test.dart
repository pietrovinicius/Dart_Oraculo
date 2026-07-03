import 'dart:typed_data';

import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:dart_oraculo/core/services/chunking_service.dart';
import 'package:dart_oraculo/core/services/pdf_service.dart';
import 'package:dart_oraculo/features/documents/document_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Cria PDF de teste com páginas.
Uint8List _createTestPdf({int pages = 2}) {
  final document = PdfDocument();
  for (var i = 1; i <= pages; i++) {
    final page = document.pages.add();
    page.graphics.drawString(
      'Conteúdo da página $i. Este é um parágrafo sobre Flutter.\n\n'
      'Segundo parágrafo da página $i com informação adicional.',
      PdfStandardFont(PdfFontFamily.helvetica, 12),
    );
  }
  final bytes = Uint8List.fromList(document.saveSync());
  document.dispose();
  return bytes;
}

void main() {
  late Database db;
  late DocumentService documentService;

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          for (final sql in Migrations.allV1) {
            await db.execute(sql);
          }
        },
      ),
    );

    documentService = DocumentService(
      database: db,
      pdfService: PdfService(),
      chunkingService: ChunkingService(),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('DocumentService', () {
    test('ingestPdf cria documento no banco', () async {
      final bytes = _createTestPdf(pages: 1);

      final doc = await documentService.ingestPdf(
        bytes: bytes,
        filename: 'test.pdf',
        sourcePath: '/tmp/test.pdf',
      );

      expect(doc.id, isNotNull);
      expect(doc.filename, equals('test.pdf'));
      expect(doc.sourcePath, equals('/tmp/test.pdf'));
    });

    test('ingestPdf persiste chunks no banco', () async {
      final bytes = _createTestPdf(pages: 2);

      final doc = await documentService.ingestPdf(
        bytes: bytes,
        filename: 'multi.pdf',
      );

      final chunks = await documentService.getChunksForDocument(doc.id!);

      expect(chunks, isNotEmpty);
      expect(chunks.first.documentId, equals(doc.id));
      expect(chunks.first.content, isNotEmpty);
    });

    test('chunks são indexados no FTS5 automaticamente', () async {
      final bytes = _createTestPdf(pages: 1);

      await documentService.ingestPdf(
        bytes: bytes,
        filename: 'fts_test.pdf',
      );

      final ftsResult = await db.rawQuery(
        "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'flutter'",
      );

      expect(ftsResult, isNotEmpty);
    });

    test('listDocuments retorna todos os documentos', () async {
      final bytes = _createTestPdf(pages: 1);

      await documentService.ingestPdf(bytes: bytes, filename: 'doc1.pdf');
      await documentService.ingestPdf(bytes: bytes, filename: 'doc2.pdf');

      final docs = await documentService.listDocuments();

      expect(docs, hasLength(2));
    });

    test('deleteDocument remove documento e chunks', () async {
      final bytes = _createTestPdf(pages: 1);

      final doc = await documentService.ingestPdf(
        bytes: bytes,
        filename: 'to_delete.pdf',
      );

      await documentService.deleteDocument(doc.id!);

      final docs = await documentService.listDocuments();
      expect(docs, isEmpty);

      final chunks = await documentService.getChunksForDocument(doc.id!);
      expect(chunks, isEmpty);
    });

    test('deleteDocument limpa FTS5 via trigger', () async {
      final bytes = _createTestPdf(pages: 1);

      final doc = await documentService.ingestPdf(
        bytes: bytes,
        filename: 'fts_delete.pdf',
      );

      await documentService.deleteDocument(doc.id!);

      final ftsResult = await db.rawQuery(
        "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'flutter'",
      );
      expect(ftsResult, isEmpty);
    });
  });
}
