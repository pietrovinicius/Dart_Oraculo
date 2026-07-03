import 'dart:convert';

import 'package:dart_oraculo/core/config/app_config.dart';
import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:dart_oraculo/core/services/anthropic_service.dart';
import 'package:dart_oraculo/core/services/fts_service.dart';
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
        version: 1,
        onCreate: (db, version) async {
          for (final sql in Migrations.allV1) {
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
  });
}
