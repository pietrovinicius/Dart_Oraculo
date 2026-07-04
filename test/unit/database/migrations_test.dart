import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

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
  });

  tearDown(() async {
    await db.close();
  });

  group('Migrations v1', () {
    test('cria tabela documents', () async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='documents'",
      );
      expect(result, hasLength(1));
    });

    test('cria tabela chunks', () async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks'",
      );
      expect(result, hasLength(1));
    });

    test('cria tabela virtual chunks_fts', () async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='chunks_fts'",
      );
      expect(result, hasLength(1));
    });

    test('cria tabela conversations', () async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='conversations'",
      );
      expect(result, hasLength(1));
    });

    test('cria tabela messages', () async {
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='messages'",
      );
      expect(result, hasLength(1));
    });

    test('trigger popula chunks_fts ao inserir chunk', () async {
      await db.insert('documents', {
        'filename': 'test.pdf',
        'imported_at': DateTime.now().toIso8601String(),
      });

      await db.insert('chunks', {
        'document_id': 1,
        'page': 1,
        'content': 'Flutter é um framework multiplataforma',
        'created_at': DateTime.now().toIso8601String(),
      });

      final ftsResult = await db.rawQuery(
        "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'flutter'",
      );
      expect(ftsResult, hasLength(1));
      expect(ftsResult.first['content'], contains('Flutter'));
    });

    test('trigger atualiza chunks_fts ao atualizar chunk', () async {
      await db.insert('documents', {
        'filename': 'test.pdf',
        'imported_at': DateTime.now().toIso8601String(),
      });

      await db.insert('chunks', {
        'document_id': 1,
        'page': 1,
        'content': 'texto original',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.update(
        'chunks',
        {'content': 'texto atualizado com Dart'},
        where: 'id = ?',
        whereArgs: [1],
      );

      final oldResult = await db.rawQuery(
        "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'original'",
      );
      expect(oldResult, isEmpty);

      final newResult = await db.rawQuery(
        "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'dart'",
      );
      expect(newResult, hasLength(1));
    });

    test('trigger remove de chunks_fts ao deletar chunk', () async {
      await db.insert('documents', {
        'filename': 'test.pdf',
        'imported_at': DateTime.now().toIso8601String(),
      });

      await db.insert('chunks', {
        'document_id': 1,
        'page': 1,
        'content': 'conteúdo para deletar',
        'created_at': DateTime.now().toIso8601String(),
      });

      await db.delete('chunks', where: 'id = ?', whereArgs: [1]);

      final result = await db.rawQuery(
        "SELECT * FROM chunks_fts WHERE chunks_fts MATCH 'deletar'",
      );
      expect(result, isEmpty);
    });

    test('messages.role aceita apenas user e assistant', () async {
      await db.insert('conversations', {
        'title': 'Test',
        'pinned': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Deve funcionar com 'user'
      await db.insert('messages', {
        'conversation_id': 1,
        'role': 'user',
        'content': 'pergunta',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Deve funcionar com 'assistant'
      await db.insert('messages', {
        'conversation_id': 1,
        'role': 'assistant',
        'content': 'resposta',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Deve falhar com role inválido
      expect(
        () async => await db.insert('messages', {
          'conversation_id': 1,
          'role': 'system',
          'content': 'inválido',
          'created_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('Migrations v2 — message_feedback', () {
    late Database dbV2;

    setUp(() async {
      dbV2 = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          singleInstance: false,
          onCreate: (db, version) async {
            for (final sql in Migrations.allV2) {
              await db.execute(sql);
            }
          },
        ),
      );

      // Seed: conversa + mensagem
      await dbV2.insert('conversations', {
        'title': 'Test',
        'pinned': 0,
        'created_at': DateTime.now().toIso8601String(),
      });
      await dbV2.insert('messages', {
        'conversation_id': 1,
        'role': 'assistant',
        'content': 'resposta teste',
        'model_used': 'claude-sonnet-4-6',
        'created_at': DateTime.now().toIso8601String(),
      });
    });

    tearDown(() async {
      await dbV2.close();
    });

    test('cria tabela message_feedback', () async {
      final result = await dbV2.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='message_feedback'",
      );
      expect(result, hasLength(1));
    });

    test('insere feedback like', () async {
      await dbV2.insert('message_feedback', {
        'message_id': 1,
        'value': 'like',
        'created_at': DateTime.now().toIso8601String(),
      });

      final rows = await dbV2.query('message_feedback');
      expect(rows, hasLength(1));
      expect(rows.first['value'], equals('like'));
    });

    test('insere feedback dislike', () async {
      await dbV2.insert('message_feedback', {
        'message_id': 1,
        'value': 'dislike',
        'created_at': DateTime.now().toIso8601String(),
      });

      final rows = await dbV2.query('message_feedback');
      expect(rows.first['value'], equals('dislike'));
    });

    test('rejeita value inválido', () async {
      expect(
        () async => await dbV2.insert('message_feedback', {
          'message_id': 1,
          'value': 'love',
          'created_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('upgrade v1 → v2 cria message_feedback', () async {
      // Simula DB v1
      final dbUpgrade = await databaseFactoryFfi.openDatabase(
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

      // Verifica que message_feedback não existe em v1
      var tables = await dbUpgrade.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='message_feedback'",
      );
      expect(tables, isEmpty);

      // Aplica upgrade
      for (final sql in Migrations.upgradeV1toV2) {
        await dbUpgrade.execute(sql);
      }

      // Agora existe
      tables = await dbUpgrade.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='message_feedback'",
      );
      expect(tables, hasLength(1));

      await dbUpgrade.close();
    });
  });
}
