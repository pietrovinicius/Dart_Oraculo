import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:dart_oraculo/core/services/anthropic_service.dart';
import 'package:dart_oraculo/core/services/chunking_service.dart';
import 'package:dart_oraculo/core/services/markdown_normalizer.dart';
import 'package:dart_oraculo/core/services/pdf_service.dart';
import 'package:dart_oraculo/features/documents/document_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
  });

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
        singleInstance: false,
        onCreate: (db, version) async {
          for (final sql in Migrations.allV7) {
            await db.execute(sql);
          }
        },
      ),
    );

    documentService = DocumentService(
      database: db,
      pdfService: PdfService(),
      chunkingService: ChunkingService(),
      markdownNormalizer: MarkdownNormalizer(),
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

  group('DocumentService — Markdown', () {
    test('ingestMarkdown cria documento e chunks', () async {
      const content = '# Título\n\nPrimeiro parágrafo sobre Dart.\n\n'
          'Segundo parágrafo com mais informação.';
      final bytes = Uint8List.fromList(utf8.encode(content));

      final doc = await documentService.ingestMarkdown(
        bytes: bytes,
        filename: 'notas.md',
        sourcePath: '/tmp/notas.md',
      );

      expect(doc.id, isNotNull);
      expect(doc.filename, equals('notas.md'));

      final chunks = await documentService.getChunksForDocument(doc.id!);
      expect(chunks, isNotEmpty);
    });

    test('ingestMarkdown indexa conteúdo no FTS5', () async {
      const content = 'Flutter é um framework multiplataforma incrível.';
      final bytes = Uint8List.fromList(utf8.encode(content));

      await documentService.ingestMarkdown(
        bytes: bytes,
        filename: 'flutter.md',
      );

      final ftsResult = await db.rawQuery(
        "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'flutter'",
      );
      expect(ftsResult, isNotEmpty);
    });

    test('ingestMarkdown chunks com page null para arquivo inteiro', () async {
      const content = 'Parágrafo único de teste.';
      final bytes = Uint8List.fromList(utf8.encode(content));

      final doc = await documentService.ingestMarkdown(
        bytes: bytes,
        filename: 'simples.md',
      );

      final chunks = await documentService.getChunksForDocument(doc.id!);
      expect(chunks, isNotEmpty);
      // page é null para markdown (arquivo inteiro)
      expect(chunks.first.page, isNull);
    });
  });

  group('DocumentService — exportAsMarkdown', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dart_oraculo_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('exporta chunks concatenados com separador \\n\\n', () async {
      const content = 'Parágrafo um.\n\nParágrafo dois.\n\nParágrafo três.';
      final bytes = Uint8List.fromList(utf8.encode(content));

      final doc = await documentService.ingestMarkdown(
        bytes: bytes,
        filename: 'export_test.md',
      );

      final exportPath = await documentService.exportAsMarkdown(
        doc.id!,
        outputDir: tempDir,
      );

      expect(exportPath, contains('export_test.md'));

      final exported = await File(exportPath).readAsString();
      expect(exported, contains('Parágrafo um.'));
      expect(exported, contains('Parágrafo dois.'));
      expect(exported, contains('Parágrafo três.'));
      expect(exported, contains('Parágrafo um.\n\nParágrafo dois.'));
    });

    test('exporta múltiplos chunks na ordem correta', () async {
      const content = 'Primeiro.\n\nSegundo.\n\nTerceiro.';
      final bytes = Uint8List.fromList(utf8.encode(content));

      final doc = await documentService.ingestMarkdown(
        bytes: bytes,
        filename: 'order_test.md',
      );

      final exportPath = await documentService.exportAsMarkdown(
        doc.id!,
        outputDir: tempDir,
      );
      final exported = await File(exportPath).readAsString();

      final firstIdx = exported.indexOf('Primeiro.');
      final secondIdx = exported.indexOf('Segundo.');
      final thirdIdx = exported.indexOf('Terceiro.');

      expect(firstIdx, lessThan(secondIdx));
      expect(secondIdx, lessThan(thirdIdx));
    });

    test('segunda chamada retorna cache sem reprocessar', () async {
      const content = 'Cache test conteúdo.';
      final bytes = Uint8List.fromList(utf8.encode(content));

      final doc = await documentService.ingestMarkdown(
        bytes: bytes,
        filename: 'cache_test.md',
      );

      final path1 = await documentService.exportAsMarkdown(
        doc.id!,
        outputDir: tempDir,
      );
      final file1Modified = File(path1).lastModifiedSync();

      // Aguarda 1ms para garantir timestamp diferente se regravasse
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final path2 = await documentService.exportAsMarkdown(
        doc.id!,
        outputDir: tempDir,
      );
      final file2Modified = File(path2).lastModifiedSync();

      // Mesmo path, mesmo timestamp (não regravou)
      expect(path1, equals(path2));
      expect(file1Modified, equals(file2Modified));
    });
  });

  group('DocumentService — _generateDescription modelo dinâmico', () {
    test('usa modelo Sonnet quando configurado', () async {
      String? modelUsed;
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        modelUsed = body['model'] as String?;
        final responseBody = [
          'event: content_block_delta\n',
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Resumo do documento."}}\n\n',
          'event: message_stop\n',
          'data: {"type":"message_stop"}\n\n',
        ].join();
        return http.Response(responseBody, 200);
      });

      final anthropic = AnthropicService(
        apiKey: 'sk-test',
        httpClient: mockClient,
        model: 'claude-sonnet-4-6',
      );

      final serviceWithAI = DocumentService(
        database: db,
        pdfService: PdfService(),
        chunkingService: ChunkingService(),
        generationService: anthropic,
      );

      const content = 'Conteúdo do documento para gerar descrição.';
      final bytes = Uint8List.fromList(utf8.encode(content));
      await serviceWithAI.ingestMarkdown(bytes: bytes, filename: 'sonnet.md');

      expect(modelUsed, equals('claude-sonnet-4-6'));
    });

    test('usa modelo Opus quando configurado', () async {
      String? modelUsed;
      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        modelUsed = body['model'] as String?;
        final responseBody = [
          'event: content_block_delta\n',
          'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Resumo Opus."}}\n\n',
          'event: message_stop\n',
          'data: {"type":"message_stop"}\n\n',
        ].join();
        return http.Response(responseBody, 200);
      });

      final anthropic = AnthropicService(
        apiKey: 'sk-test',
        httpClient: mockClient,
        model: 'claude-opus-4-8',
      );

      final serviceWithAI = DocumentService(
        database: db,
        pdfService: PdfService(),
        chunkingService: ChunkingService(),
        generationService: anthropic,
      );

      const content = 'Outro conteúdo para testar Opus.';
      final bytes = Uint8List.fromList(utf8.encode(content));
      await serviceWithAI.ingestMarkdown(bytes: bytes, filename: 'opus.md');

      expect(modelUsed, equals('claude-opus-4-8'));
    });
  });

  group('DocumentService — ingestStructuredData', () {
    test('ingere CSV agrupado por coluna', () async {
      const csvContent = 'TABLE_NAME,COLUMN_NAME,DATA_TYPE\n'
          'PACIENTE,CD_PACIENTE,NUMBER\n'
          'PACIENTE,NM_PACIENTE,VARCHAR2\n'
          'MEDICO,CD_MEDICO,NUMBER\n'
          'MEDICO,NM_MEDICO,VARCHAR2\n';
      final bytes = Uint8List.fromList(utf8.encode(csvContent));

      final doc = await documentService.ingestStructuredData(
        bytes: bytes,
        filename: 'tab_columns.csv',
        groupByColumn: 'TABLE_NAME',
      );

      expect(doc.id, isNotNull);
      expect(doc.filename, equals('tab_columns.csv'));

      final chunks = await documentService.getChunksForDocument(doc.id!);
      // 2 tabelas = 2 chunks
      expect(chunks, hasLength(2));
      expect(chunks[0].content, contains('PACIENTE'));
      expect(chunks[1].content, contains('MEDICO'));
    });

    test('ingere JSON agrupado por coluna', () async {
      final jsonContent = jsonEncode([
        {'TRIGGER_NAME': 'TRG_PACIENTE', 'TABLE_NAME': 'PACIENTE', 'STATUS': 'ENABLED'},
        {'TRIGGER_NAME': 'TRG_PACIENTE', 'TABLE_NAME': 'PACIENTE', 'STATUS': 'ENABLED'},
        {'TRIGGER_NAME': 'TRG_MEDICO', 'TABLE_NAME': 'MEDICO', 'STATUS': 'DISABLED'},
      ]);
      final bytes = Uint8List.fromList(utf8.encode(jsonContent));

      final doc = await documentService.ingestStructuredData(
        bytes: bytes,
        filename: 'triggers.json',
        groupByColumn: 'TRIGGER_NAME',
      );

      expect(doc.id, isNotNull);

      final chunks = await documentService.getChunksForDocument(doc.id!);
      expect(chunks, hasLength(2));
      expect(chunks[0].content, contains('TRG_PACIENTE'));
      expect(chunks[1].content, contains('TRG_MEDICO'));
    });

    test('chunks de dados estruturados são indexados no FTS5', () async {
      const csvContent = 'TABLE_NAME,COLUMN_NAME\n'
          'PACIENTE,CD_PACIENTE\n';
      final bytes = Uint8List.fromList(utf8.encode(csvContent));

      await documentService.ingestStructuredData(
        bytes: bytes,
        filename: 'fts_structured.csv',
        groupByColumn: 'TABLE_NAME',
      );

      final ftsResult = await db.rawQuery(
        "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'PACIENTE'",
      );
      expect(ftsResult, isNotEmpty);
    });
  });

  group('DocumentService — batch inserts + isolate', () {
    test('ingestStructuredData com volume grande usa batch (1500+ rows)', () async {
      // Gera CSV sintético com 1500 rows (forçará pelo menos 2 batches de 1000)
      final buffer = StringBuffer();
      buffer.writeln('TABLE_NAME,COLUMN_NAME,DATA_TYPE');
      for (var i = 0; i < 1500; i++) {
        final table = 'TABLE_${i ~/ 10}';
        buffer.writeln('$table,COL_$i,VARCHAR2');
      }
      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));

      var progressCalls = 0;
      final doc = await documentService.ingestStructuredData(
        bytes: bytes,
        filename: 'big_batch.csv',
        groupByColumn: 'TABLE_NAME',
        onProgress: (_) => progressCalls++,
      );

      expect(doc.id, isNotNull);

      // 1500 rows / 10 per table = 150 grupos/chunks
      final chunks = await documentService.getChunksForDocument(doc.id!);
      expect(chunks, hasLength(150));

      // Progresso chamado múltiplas vezes (não apenas 2 ticks)
      expect(progressCalls, greaterThan(3));
    });

    test('progresso granular reporta por batch processado', () async {
      final buffer = StringBuffer();
      buffer.writeln('TABLE_NAME,COLUMN_NAME');
      for (var i = 0; i < 100; i++) {
        buffer.writeln('T_$i,C_$i');
      }
      final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));

      final progressValues = <double>[];
      await documentService.ingestStructuredData(
        bytes: bytes,
        filename: 'progress_test.csv',
        groupByColumn: 'TABLE_NAME',
        onProgress: (p) => progressValues.add(p),
      );

      // Progresso deve ser monotonicamente crescente
      for (var i = 1; i < progressValues.length; i++) {
        expect(progressValues[i], greaterThanOrEqualTo(progressValues[i - 1]));
      }
      // Deve terminar em ~1.0
      expect(progressValues.last, closeTo(1.0, 0.01));
    });
  });
}
