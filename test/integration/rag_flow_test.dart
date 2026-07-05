import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_oraculo/core/config/app_config.dart';
import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:dart_oraculo/core/services/anthropic_service.dart';
import 'package:dart_oraculo/core/services/chunking_service.dart';
import 'package:dart_oraculo/core/services/fts_service.dart';
import 'package:dart_oraculo/core/services/pdf_service.dart';
import 'package:dart_oraculo/features/chat/chat_controller.dart';
import 'package:dart_oraculo/features/documents/document_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Cria PDF com conteúdo sobre um tema.
Uint8List _createPdf(String topic, List<String> paragraphs) {
  final document = PdfDocument();
  for (final paragraph in paragraphs) {
    final page = document.pages.add();
    page.graphics.drawString(
      paragraph,
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
  late ChatController chatController;
  late String lastRequestBody;

  setUpAll(() {
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
    );

    final mockClient = MockClient((request) async {
      lastRequestBody = request.body;
      final responseBody = [
        'event: content_block_delta\n',
        'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Resposta baseada no contexto."}}\n\n',
        'event: message_stop\n',
        'data: {"type":"message_stop"}\n\n',
      ].join();
      return http.Response(responseBody, 200);
    });

    chatController = ChatController(
      database: db,
      anthropicService: AnthropicService(
        apiKey: 'sk-test-integration',
        httpClient: mockClient,
      ),
      ftsService: FtsService(database: db),
    );
  });

  tearDown(() async {
    chatController.dispose();
    await db.close();
  });

  group('Fluxo RAG End-to-End', () {
    test('ingestão → busca → resposta com citação', () async {
      // 1. Ingestão de dois PDFs com assuntos diferentes
      final flutterPdf = _createPdf('Flutter', [
        'Flutter é um framework multiplataforma criado pelo Google.',
        'Widgets são os componentes fundamentais do Flutter.',
      ]);

      final dartPdf = _createPdf('Dart', [
        'Dart é a linguagem de programação usada pelo Flutter.',
        'Dart suporta null safety desde a versão 2.12.',
      ]);

      await documentService.ingestPdf(
        bytes: flutterPdf,
        filename: 'flutter_guide.pdf',
      );
      await documentService.ingestPdf(
        bytes: dartPdf,
        filename: 'dart_reference.pdf',
      );

      // 2. Verifica que documentos foram indexados
      final docs = await documentService.listDocuments();
      expect(docs, hasLength(2));

      // 3. Busca FTS5 funciona
      final fts = FtsService(database: db);
      final searchResults = await fts.search('Flutter framework');
      expect(searchResults, isNotEmpty);
      expect(searchResults.first.filename, equals('flutter_guide.pdf'));

      // 4. Faz pergunta via chat
      final conv = await chatController.createConversation(
        title: 'Teste RAG',
      );

      final responseChunks = <String>[];
      await for (final chunk in chatController.askQuestion(
        conversationId: conv.id!,
        question: 'O que é Flutter?',
        model: AppConfig.modelSonnet,
      )) {
        responseChunks.add(chunk);
      }

      // 5. Verifica resposta
      expect(responseChunks.join(), equals('Resposta baseada no contexto.'));

      // 6. Verifica que o contexto enviado à API contém chunks relevantes
      final requestJson = jsonDecode(lastRequestBody) as Map<String, dynamic>;
      final system = requestJson['system'] as String;
      expect(system, contains('Flutter'));
      expect(system, contains('CONTEXTO'));

      // 7. Verifica mensagens persistidas com chunks_used
      final messages = await chatController.getMessages(conv.id!);
      expect(messages, hasLength(2));

      final userMsg = messages[0];
      expect(userMsg.role, equals('user'));
      expect(userMsg.content, equals('O que é Flutter?'));

      final assistantMsg = messages[1];
      expect(assistantMsg.role, equals('assistant'));
      expect(assistantMsg.chunksUsed, isNotNull);

      final chunkIds = jsonDecode(assistantMsg.chunksUsed!) as List;
      expect(chunkIds, isNotEmpty);
    });

    test('resposta funciona mesmo sem documentos indexados', () async {
      final conv = await chatController.createConversation(
        title: 'Sem docs',
      );

      final response = StringBuffer();
      await for (final chunk in chatController.askQuestion(
        conversationId: conv.id!,
        question: 'Pergunta sem contexto',
        model: AppConfig.modelSonnet,
      )) {
        response.write(chunk);
      }

      expect(response.toString(), isNotEmpty);

      final messages = await chatController.getMessages(conv.id!);
      expect(messages, hasLength(2));
      // chunks_used deve ser lista vazia
      final chunkIds = jsonDecode(messages[1].chunksUsed!) as List;
      expect(chunkIds, isEmpty);
    });

    test('múltiplas perguntas na mesma conversa mantêm histórico', () async {
      final pdf = _createPdf('Teste', [
        'Informação relevante para o teste de histórico.',
      ]);
      await documentService.ingestPdf(bytes: pdf, filename: 'hist.pdf');

      final conv = await chatController.createConversation(
        title: 'Histórico',
      );

      // Primeira pergunta
      await chatController.askQuestion(
        conversationId: conv.id!,
        question: 'Primeira pergunta',
        model: AppConfig.modelSonnet,
      ).toList();

      // Segunda pergunta
      await chatController.askQuestion(
        conversationId: conv.id!,
        question: 'Segunda pergunta',
        model: AppConfig.modelSonnet,
      ).toList();

      // Verifica que request da segunda pergunta inclui histórico
      final requestJson = jsonDecode(lastRequestBody) as Map<String, dynamic>;
      final messages = requestJson['messages'] as List;
      // Deve ter: hist user + hist assistant + user atual = 3
      expect(messages.length, greaterThanOrEqualTo(3));

      // Verifica persistência
      final allMessages = await chatController.getMessages(conv.id!);
      expect(allMessages, hasLength(4)); // 2 perguntas + 2 respostas
    });
  });
}
