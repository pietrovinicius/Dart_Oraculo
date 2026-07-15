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

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 6,
        singleInstance: false,
        onCreate: (db, version) async {
          for (final sql in Migrations.allV10) {
            await db.execute(sql);
          }
        },
      ),
    );

    // Mock HTTP client
    final mockClient = MockClient((request) async {
      final responseBody = 'event: message_start\n'
          'data: {"type":"message_start","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":100}}}\n\n'
          'event: content_block_delta\n'
          'data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"Resposta teste"}}\n\n'
          'event: message_delta\n'
          'data: {"type":"message_delta","delta":{"stop_reason":"end_turn"},"usage":{"output_tokens":50}}\n\n';
      return http.Response(responseBody, 200);
    });

    final anthropicService = AnthropicService(
      apiKey: 'sk-test-invalid-key-12345',
      httpClient: mockClient,
    );
    final ftsService = FtsService(database: db);

    controller = ChatController(
      database: db,
      anthropicService: anthropicService,
      ftsService: ftsService,
      secureStorage: SecureStorageService.test(testStore: {}),
    );

    // Seed: coleção + conversa + mensagens
    await db.insert('collections', {
      'name': 'TASY',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('conversations', {
      'title': 'Test Conv',
      'collection_id': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('messages', {
      'conversation_id': 1,
      'role': 'user',
      'content': 'O que é ADEP_V?',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('messages', {
      'conversation_id': 1,
      'role': 'assistant',
      'content': 'ADEP_V é uma view do TASY para adequação.',
      'model_used': 'claude-sonnet-4-6',
      'created_at': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async => db.close());

  group('Promoção de respostas', () {
    test('like promove resposta como chunk pesquisável', () async {
      // Dá like na mensagem 2 (assistant)
      await controller.setFeedback(2, 'like');

      // Verifica chunk promovido existe
      final chunks = await db.query(
        'chunks',
        where: 'source_type = ? AND original_message_id = ?',
        whereArgs: ['promoted_answer', 2],
      );
      expect(chunks, hasLength(1));
      expect(chunks.first['content'] as String, contains('ADEP_V'));
      expect(chunks.first['content'] as String, contains('Resposta aprovada'));
      expect(chunks.first['content'] as String, contains('TASY'));
    });

    test('like cria documento sintético na primeira promoção', () async {
      await controller.setFeedback(2, 'like');

      final docs = await db.query(
        'documents',
        where: 'filename = ?',
        whereArgs: ['Respostas Aprovadas do Oráculo'],
      );
      expect(docs, hasLength(1));
      expect(docs.first['collection_id'], 1);
    });

    test('remover like deleta chunk promovido', () async {
      // Promove
      await controller.setFeedback(2, 'like');
      var chunks = await db.query('chunks', where: 'source_type = ?', whereArgs: ['promoted_answer']);
      expect(chunks, hasLength(1));

      // Remove like (toggle off)
      await controller.setFeedback(2, 'like');
      chunks = await db.query('chunks', where: 'source_type = ?', whereArgs: ['promoted_answer']);
      expect(chunks, isEmpty);
    });

    test('dislike direto não promove', () async {
      await controller.setFeedback(2, 'dislike');

      final chunks = await db.query('chunks', where: 'source_type = ?', whereArgs: ['promoted_answer']);
      expect(chunks, isEmpty);
    });

    test('trocar like para dislike reverte promoção', () async {
      await controller.setFeedback(2, 'like');
      var chunks = await db.query('chunks', where: 'source_type = ?', whereArgs: ['promoted_answer']);
      expect(chunks, hasLength(1));

      // Troca para dislike
      await controller.setFeedback(2, 'dislike');
      chunks = await db.query('chunks', where: 'source_type = ?', whereArgs: ['promoted_answer']);
      expect(chunks, isEmpty);
    });

    test('chunk promovido é pesquisável via FTS5', () async {
      await controller.setFeedback(2, 'like');

      final fts = FtsService(database: db);
      final results = await fts.search('ADEP_V', collectionId: 1);
      expect(results, isNotEmpty);
      expect(results.any((r) => r.content.contains('Resposta aprovada')), isTrue);
    });
  });
}
