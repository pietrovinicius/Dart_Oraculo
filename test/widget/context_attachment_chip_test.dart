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
        version: 8,
        singleInstance: false,
        onCreate: (db, version) async {
          for (final sql in Migrations.allV8) {
            await db.execute(sql);
          }
        },
      ),
    );

    final mockClient = MockClient((request) async => http.Response('', 200));
    controller = ChatController(
      database: db,
      anthropicService: AnthropicService(
        apiKey: 'sk-test-12345678',
        httpClient: mockClient,
      ),
      ftsService: FtsService(database: db),
    );

    await db.insert('collections', {
      'name': 'Test',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('conversations', {
      'title': 'Conv1',
      'collection_id': 1,
      'pinned': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async => db.close());

  group('Context attachment remoção efetiva', () {
    test('removeContextAttachment deleta registro do banco', () async {
      // Adiciona
      await controller.addContextAttachment(1, 'spec.md', 'conteúdo spec');
      var atts = await controller.getContextAttachments(1);
      expect(atts, hasLength(1));
      final id = atts.first['id'] as int;

      // Remove
      await controller.removeContextAttachment(id);

      // Verifica que não existe mais no banco
      atts = await controller.getContextAttachments(1);
      expect(atts, isEmpty);

      // Verifica direto no banco
      final rows = await db.query('conversation_context_attachments');
      expect(rows, isEmpty);
    });

    test('múltiplos anexos coexistem e remoção de um preserva outros', () async {
      await controller.addContextAttachment(1, 'a.md', 'conteúdo A');
      await controller.addContextAttachment(1, 'b.md', 'conteúdo B');

      var atts = await controller.getContextAttachments(1);
      expect(atts, hasLength(2));

      // Remove o primeiro
      await controller.removeContextAttachment(atts.first['id'] as int);

      atts = await controller.getContextAttachments(1);
      expect(atts, hasLength(1));
      expect(atts.first['filename'], 'b.md');
    });
  });
}
