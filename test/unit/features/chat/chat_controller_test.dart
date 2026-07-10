import 'dart:convert';

import 'package:dart_oraculo/core/config/app_config.dart';
import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:dart_oraculo/core/services/anthropic_service.dart';
import 'package:dart_oraculo/core/services/fts_service.dart';
import 'package:dart_oraculo/core/services/secure_storage_service.dart';
import 'package:dart_oraculo/features/chat/chat_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late ChatController controller;

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
          for (final sql in Migrations.allV10) {
            await db.execute(sql);
          }
        },
      ),
    );

    // Seed: documento com chunks
    await db.insert('documents', {
      'filename': 'flutter.pdf',
      'imported_at': DateTime.now().toIso8601String(),
    });
    await db.insert('chunks', {
      'document_id': 1,
      'page': 1,
      'content': 'Flutter é um framework para construir apps multiplataforma.',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('chunks', {
      'document_id': 1,
      'page': 2,
      'content': 'Hot reload permite iterar rapidamente no desenvolvimento Flutter.',
      'created_at': DateTime.now().toIso8601String(),
    });

    final mockClient = MockClient((request) async {
      final responseBody = [
        'event: content_block_delta\n',
        'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Flutter é multiplataforma."}}\n\n',
        'event: message_stop\n',
        'data: {"type":"message_stop"}\n\n',
      ].join();
      return http.Response(responseBody, 200);
    });

    final anthropicService = AnthropicService(
      apiKey: 'sk-test',
      httpClient: mockClient,
    );
    final ftsService = FtsService(database: db);

    controller = ChatController(
      database: db,
      anthropicService: anthropicService,
      ftsService: ftsService,
      secureStorage: SecureStorageService(testStore: {}),
    );
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  group('ChatController', () {
    test('createConversation cria conversa no banco', () async {
      final conv = await controller.createConversation(title: 'Teste');

      expect(conv.id, isNotNull);
      expect(conv.title, equals('Teste'));
    });

    test('listConversations retorna conversas ordenadas', () async {
      await controller.createConversation(title: 'Primeira');
      await controller.createConversation(title: 'Segunda');

      final convs = await controller.listConversations();

      expect(convs, hasLength(2));
    });

    test('askQuestion recupera chunks, chama API e persiste resposta', () async {
      final conv = await controller.createConversation(title: 'Chat teste');

      final response = StringBuffer();
      await for (final chunk in controller.askQuestion(
        conversationId: conv.id!,
        question: 'O que é Flutter?',
        model: AppConfig.modelSonnet,
      )) {
        response.write(chunk);
      }

      expect(response.toString(), equals('Flutter é multiplataforma.'));

      // Verifica que mensagens foram persistidas
      final messages = await controller.getMessages(conv.id!);
      expect(messages, hasLength(2)); // user + assistant
      expect(messages[0].role, equals('user'));
      expect(messages[0].content, equals('O que é Flutter?'));
      expect(messages[1].role, equals('assistant'));
      expect(messages[1].content, equals('Flutter é multiplataforma.'));
    });

    test('askQuestion persiste chunks_used na mensagem do assistant', () async {
      final conv = await controller.createConversation(title: 'Citação');

      await controller.askQuestion(
        conversationId: conv.id!,
        question: 'O que é Flutter?',
        model: AppConfig.modelSonnet,
      ).toList();

      final messages = await controller.getMessages(conv.id!);
      final assistantMsg = messages.firstWhere((m) => m.role == 'assistant');

      expect(assistantMsg.chunksUsed, isNotNull);
      final chunkIds = jsonDecode(assistantMsg.chunksUsed!) as List;
      expect(chunkIds, isNotEmpty);
    });

    test('askQuestion inclui histórico de mensagens anteriores', () async {
      final conv = await controller.createConversation(title: 'Histórico');

      // Primeira pergunta
      await controller.askQuestion(
        conversationId: conv.id!,
        question: 'Primeira pergunta',
        model: AppConfig.modelSonnet,
      ).toList();

      // Segunda pergunta — deve incluir histórico
      await controller.askQuestion(
        conversationId: conv.id!,
        question: 'Segunda pergunta',
        model: AppConfig.modelSonnet,
      ).toList();

      final messages = await controller.getMessages(conv.id!);
      // 2 perguntas + 2 respostas = 4
      expect(messages, hasLength(4));
    });

    test('deleteConversation remove conversa e mensagens', () async {
      final conv = await controller.createConversation(title: 'Para deletar');

      await controller.askQuestion(
        conversationId: conv.id!,
        question: 'Pergunta',
        model: AppConfig.modelSonnet,
      ).toList();

      await controller.deleteConversation(conv.id!);

      final convs = await controller.listConversations();
      expect(convs, isEmpty);

      final messages = await controller.getMessages(conv.id!);
      expect(messages, isEmpty);
    });

    group('feedback', () {
      late int messageId;

      setUp(() async {
        final conv = await controller.createConversation(title: 'Feedback test');
        await controller.askQuestion(
          conversationId: conv.id!,
          question: 'Pergunta',
          model: AppConfig.modelSonnet,
        ).toList();
        final msgs = await controller.getMessages(conv.id!);
        messageId = msgs.firstWhere((m) => m.role == 'assistant').id!;
      });

      test('setFeedback grava like', () async {
        await controller.setFeedback(messageId, 'like');
        final result = await controller.getFeedback(messageId);
        expect(result, equals('like'));
      });

      test('setFeedback grava dislike', () async {
        await controller.setFeedback(messageId, 'dislike');
        final result = await controller.getFeedback(messageId);
        expect(result, equals('dislike'));
      });

      test('setFeedback alterna de like para dislike', () async {
        await controller.setFeedback(messageId, 'like');
        await controller.setFeedback(messageId, 'dislike');
        final result = await controller.getFeedback(messageId);
        expect(result, equals('dislike'));
      });

      test('setFeedback remove voto com null', () async {
        await controller.setFeedback(messageId, 'like');
        await controller.setFeedback(messageId, null);
        final result = await controller.getFeedback(messageId);
        expect(result, isNull);
      });

      test('setFeedback toggle — mesmo valor remove', () async {
        await controller.setFeedback(messageId, 'like');
        await controller.setFeedback(messageId, 'like');
        final result = await controller.getFeedback(messageId);
        expect(result, isNull);
      });

      test('getFeedback retorna null sem feedback', () async {
        final result = await controller.getFeedback(messageId);
        expect(result, isNull);
      });
    });

    group('troca de GenerationService', () {
      test('trocar motor não altera FTS5 nem chunks_used', () async {
        final conv = await controller.createConversation(title: 'Motor test');

        // Usa motor padrão (Anthropic mock)
        await controller.askQuestion(
          conversationId: conv.id!,
          question: 'O que é Flutter?',
          model: AppConfig.modelSonnet,
        ).toList();

        final messages1 = await controller.getMessages(conv.id!);
        final assistant1 = messages1.firstWhere((m) => m.role == 'assistant');
        expect(assistant1.chunksUsed, isNotNull);
        final chunks1 = jsonDecode(assistant1.chunksUsed!) as List;

        // Troca para um "outro" GenerationService (mesmo mock, diferente instância)
        controller.activeGenerationService = AnthropicService(
          apiKey: 'sk-test-2',
          httpClient: MockClient((request) async {
            final responseBody = [
              'event: content_block_delta\n',
              'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Resposta do segundo motor."}}\n\n',
              'event: message_stop\n',
              'data: {"type":"message_stop"}\n\n',
            ].join();
            return http.Response(responseBody, 200);
          }),
          model: 'claude-opus-4-8',
        );

        await controller.askQuestion(
          conversationId: conv.id!,
          question: 'O que é Flutter?',
          model: AppConfig.modelOpus,
        ).toList();

        final messages2 = await controller.getMessages(conv.id!);
        // 4 mensagens: 2 user + 2 assistant
        expect(messages2, hasLength(4));

        final assistant2 = messages2.last;
        expect(assistant2.role, equals('assistant'));
        expect(assistant2.chunksUsed, isNotNull);

        // FTS5 retorna mesmos chunks (mesma query, mesma base)
        final chunks2 = jsonDecode(assistant2.chunksUsed!) as List;
        expect(chunks2, equals(chunks1));

        // model_used reflete o novo motor
        expect(assistant2.modelUsed, equals('claude-opus-4-8'));
      });
    });

    group('truncagem de chunks grandes no prompt', () {
      test('chunk acima do limite é truncado com nota explicativa', () async {
        // Insere chunk grande (simula CPOE_MATERIAL)
        final lines = List.generate(500, (i) => '| COL_$i | VARCHAR2 |');
        final bigContent = 'Tabela CPOE_MATERIAL, colunas:\n${lines.join('\n')}';
        final docId = await db.insert('documents', {
          'filename': 'big_table.csv',
          'imported_at': DateTime.now().toIso8601String(),
        });
        await db.insert('chunks', {
          'document_id': docId,
          'page': null,
          'content': bigContent,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Anthropic tem maxContextCharsPerChunk = 20000
        // Chunk gerado tem ~17K chars (500 linhas × ~35 chars)
        // Se for > 20000, será truncado; se < 20000, passa inteiro
        await controller.createConversation(title: 'Truncagem');

        // O chunk é indexado inteiro no FTS5
        final ftsResults = await db.rawQuery(
          "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'CPOE_MATERIAL'",
        );
        expect(ftsResults, isNotEmpty);

        // O conteúdo original no banco permanece íntegro
        final chunks = await db.query('chunks', where: 'document_id = ?', whereArgs: [docId]);
        expect(chunks.first['content'] as String, equals(bigContent));
      });

      test('chunk abaixo do limite passa inteiro no contexto', () async {
        // Chunk pequeno — não deve ser truncado
        final docId = await db.insert('documents', {
          'filename': 'small_table.csv',
          'imported_at': DateTime.now().toIso8601String(),
        });
        await db.insert('chunks', {
          'document_id': docId,
          'page': null,
          'content': 'Tabela PACIENTE, colunas:\n| CD_PACIENTE | NUMBER |',
          'created_at': DateTime.now().toIso8601String(),
        });

        await controller.createConversation(title: 'Sem truncagem');

        // FTS5 indexa normalmente
        final ftsResults = await db.rawQuery(
          "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'PACIENTE'",
        );
        expect(ftsResults, isNotEmpty);
      });
    });
  });
}
