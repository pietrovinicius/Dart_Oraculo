import 'dart:convert';

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
  late String lastRequestBody;

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 8,
        singleInstance: false,
        onCreate: (db, version) async {
          for (final sql in Migrations.allV9) {
            await db.execute(sql);
          }
        },
      ),
    );

    final mockClient = MockClient((request) async {
      lastRequestBody = request.body;
      final responseBody = 'event: content_block_delta\n'
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"OK"}}\n\n'
          'event: message_stop\n'
          'data: {"type":"message_stop"}\n\n';
      return http.Response(responseBody, 200);
    });

    final anthropicService = AnthropicService(
      apiKey: 'sk-test-key-12345678',
      httpClient: mockClient,
    );
    final ftsService = FtsService(database: db);

    controller = ChatController(
      database: db,
      anthropicService: anthropicService,
      ftsService: ftsService,
    );

    // Seed
    await db.insert('collections', {
      'name': 'Dev',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('conversations', {
      'title': 'Test',
      'collection_id': 1,
      'pinned': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async => db.close());

  group('Context Attachments', () {
    test('injeção do conteúdo anexado em perguntas subsequentes', () async {
      // Adiciona attachment
      await controller.addContextAttachment(
        1,
        'spec.md',
        '# Especificação\nEste é o spec do projeto.',
      );

      // Faz pergunta
      await controller.askQuestion(
        conversationId: 1,
        question: 'O que diz o spec?',
        model: 'claude-sonnet-4-6',
        collectionId: 1,
      ).toList();

      // Verifica que o body enviado contém o conteúdo do attachment
      final body = jsonDecode(lastRequestBody) as Map<String, dynamic>;
      final system = body['system'] as String;
      expect(system, contains('DOCUMENTO DE TRABALHO: spec.md'));
      expect(system, contains('Especificação'));
    });

    test('truncagem quando conteúdo excede limite do motor', () async {
      // Cria conteúdo maior que maxContextCharsPerChunk (20000 para Anthropic)
      final bigContent = 'x' * 25000;
      await controller.addContextAttachment(1, 'big.md', bigContent);

      await controller.askQuestion(
        conversationId: 1,
        question: 'resumo',
        model: 'claude-sonnet-4-6',
        collectionId: 1,
      ).toList();

      final body = jsonDecode(lastRequestBody) as Map<String, dynamic>;
      final system = body['system'] as String;
      expect(system, contains('documento de trabalho truncado'));
      // Não deve conter o conteúdo completo
      expect(system.length, lessThan(bigContent.length));
    });

    test('ausência de injeção depois que anexo removido', () async {
      await controller.addContextAttachment(1, 'temp.md', 'conteúdo temporário');

      // Busca o ID do attachment
      final atts = await controller.getContextAttachments(1);
      expect(atts, hasLength(1));
      final attId = atts.first['id'] as int;

      // Remove
      await controller.removeContextAttachment(attId);

      // Faz pergunta
      await controller.askQuestion(
        conversationId: 1,
        question: 'algo',
        model: 'claude-sonnet-4-6',
        collectionId: 1,
      ).toList();

      final body = jsonDecode(lastRequestBody) as Map<String, dynamic>;
      final system = body['system'] as String;
      expect(system, isNot(contains('conteúdo temporário')));
    });
  });
}
