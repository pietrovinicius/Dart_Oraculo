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

  setUpAll(() => sqfliteFfiInit());

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 7,
        singleInstance: false,
        onCreate: (db, version) async {
          for (final sql in Migrations.allV8) {
            await db.execute(sql);
          }
        },
      ),
    );

    final mockClient = MockClient((request) async => http.Response('', 200));
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
      'name': 'TASY',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('conversations', {
      'title': 'ADEP',
      'collection_id': 1,
      'pinned': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
    // Documento para citações
    await db.insert('documents', {
      'filename': 'tabelas_e_colunas.json',
      'collection_id': 1,
      'imported_at': DateTime.now().toIso8601String(),
    });
    await db.insert('chunks', {
      'document_id': 1,
      'page': 1,
      'content': 'Tabela ADEP_V, colunas...',
      'source_type': 'document',
      'created_at': DateTime.now().toIso8601String(),
    });
    // Chunk promovido
    await db.insert('documents', {
      'filename': 'Respostas Aprovadas do Oráculo',
      'collection_id': 1,
      'imported_at': DateTime.now().toIso8601String(),
    });
    await db.insert('chunks', {
      'document_id': 2,
      'page': null,
      'content': 'Resposta aprovada...',
      'source_type': 'promoted_answer',
      'original_message_id': 99,
      'created_at': '2026-07-05T10:00:00.000',
    });
    // Mensagens
    await db.insert('messages', {
      'conversation_id': 1,
      'role': 'user',
      'content': 'O que é ADEP_V?',
      'created_at': '2026-07-05T15:34:00.000',
    });
    await db.insert('messages', {
      'conversation_id': 1,
      'role': 'assistant',
      'content': 'ADEP_V é uma view do TASY.',
      'model_used': 'claude-sonnet-4-6',
      'chunks_used': '[1, 2]',
      'created_at': '2026-07-05T15:34:10.000',
    });
    await db.insert('messages', {
      'conversation_id': 1,
      'role': 'user',
      'content': 'tem procedure?',
      'image_path': '/tmp/img.png',
      'created_at': '2026-07-05T15:35:00.000',
    });
    await db.insert('messages', {
      'conversation_id': 1,
      'role': 'assistant',
      'content': 'Sim, ADEP_OBTER_CCG.',
      'model_used': 'claude-sonnet-4-6',
      'chunks_used': '[1]',
      'created_at': '2026-07-05T15:35:10.000',
    });
  });

  tearDown(() async => db.close());

  group('exportConversationAsMarkdown', () {
    test('gera markdown com cabeçalho, mensagens e fontes', () async {
      final md = await controller.exportConversationAsMarkdown(1);

      expect(md, contains('# Conversa: ADEP'));
      expect(md, contains('Coleção: TASY'));
      expect(md, contains('## 👤 Usuário'));
      expect(md, contains('O que é ADEP_V?'));
      expect(md, contains('## 🤖 Assistente'));
      expect(md, contains('claude-sonnet-4-6'));
      expect(md, contains('ADEP_V é uma view do TASY.'));
      expect(md, contains('**Fontes:**'));
    });

    test('inclui nota de imagem anexada', () async {
      final md = await controller.exportConversationAsMarkdown(1);

      expect(md, contains('📎 *[imagem anexada]*'));
    });

    test('diferencia citação de documento e resposta promovida', () async {
      final md = await controller.exportConversationAsMarkdown(1);

      expect(md, contains('tabelas_e_colunas.json (p.1)'));
      expect(md, contains('Resposta aprovada'));
    });
  });
}
