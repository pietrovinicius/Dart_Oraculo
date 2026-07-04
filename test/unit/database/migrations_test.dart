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

    test('upgrade v1 → v2 adiciona pinned e message_feedback', () async {
      // Schema v1 ORIGINAL (sem coluna pinned)
      const originalCreateConversations = '''
        CREATE TABLE IF NOT EXISTS conversations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          created_at TEXT NOT NULL
        );
      ''';

      final dbUpgrade = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, version) async {
            await db.execute(Migrations.createDocuments);
            await db.execute(Migrations.createChunks);
            await db.execute(Migrations.createChunksFts);
            await db.execute(Migrations.triggerInsert);
            await db.execute(Migrations.triggerDelete);
            await db.execute(Migrations.triggerUpdate);
            await db.execute(originalCreateConversations);
            await db.execute(Migrations.createMessages);
          },
        ),
      );

      // Verifica que pinned e message_feedback não existem em v1 original
      var tables = await dbUpgrade.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='message_feedback'",
      );
      expect(tables, isEmpty);

      // Aplica upgrade v1→v2
      for (final sql in Migrations.upgradeV1toV2) {
        await dbUpgrade.execute(sql);
      }

      // message_feedback existe
      tables = await dbUpgrade.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='message_feedback'",
      );
      expect(tables, hasLength(1));

      // pinned existe em conversations
      final convInfo = await dbUpgrade.rawQuery('PRAGMA table_info(conversations)');
      final hasPinned = convInfo.any((col) => col['name'] == 'pinned');
      expect(hasPinned, isTrue);

      await dbUpgrade.close();
    });
  });

  group('Migrations v3 — collections', () {
    late Database dbV3;

    setUp(() async {
      dbV3 = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          singleInstance: false,
          onCreate: (db, version) async {
            for (final sql in Migrations.allV3) {
              await db.execute(sql);
            }
            // Simula fresh install: cria coleção Geral
            await db.insert('collections', {
              'name': 'Geral',
              'instructions': null,
              'created_at': DateTime.now().toIso8601String(),
            });
          },
        ),
      );
    });

    tearDown(() async {
      await dbV3.close();
    });

    test('cria tabela collections', () async {
      final result = await dbV3.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='collections'",
      );
      expect(result, hasLength(1));
    });

    test('documents tem coluna collection_id', () async {
      final info = await dbV3.rawQuery('PRAGMA table_info(documents)');
      final hasCol = info.any((col) => col['name'] == 'collection_id');
      expect(hasCol, isTrue);
    });

    test('conversations tem coluna collection_id', () async {
      final info = await dbV3.rawQuery('PRAGMA table_info(conversations)');
      final hasCol = info.any((col) => col['name'] == 'collection_id');
      expect(hasCol, isTrue);
    });

    test('coleção Geral criada no fresh install', () async {
      final rows = await dbV3.query('collections');
      expect(rows, hasLength(1));
      expect(rows.first['name'], equals('Geral'));
    });

    test('upgrade v2 → v3 cria collections e faz backfill', () async {
      // Simula DB v2 com dados
      final dbUp = await databaseFactoryFfi.openDatabase(
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

      // Insere dados pré-existentes
      await dbUp.insert('documents', {
        'filename': 'old.pdf',
        'imported_at': DateTime.now().toIso8601String(),
      });
      await dbUp.insert('conversations', {
        'title': 'Old conv',
        'pinned': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Aplica upgrade v2→v3
      for (final sql in Migrations.upgradeV2toV3Schema) {
        await dbUp.execute(sql);
      }
      final geralId = await dbUp.insert('collections', {
        'name': 'Geral',
        'instructions': null,
        'created_at': DateTime.now().toIso8601String(),
      });
      await dbUp.execute(
        'UPDATE documents SET collection_id = ? WHERE collection_id IS NULL',
        [geralId],
      );
      await dbUp.execute(
        'UPDATE conversations SET collection_id = ? WHERE collection_id IS NULL',
        [geralId],
      );

      // Verifica: nenhum órfão
      final docs = await dbUp.query('documents');
      expect(docs.first['collection_id'], equals(geralId));

      final convs = await dbUp.query('conversations');
      expect(convs.first['collection_id'], equals(geralId));

      // Collections existe
      final collections = await dbUp.query('collections');
      expect(collections, hasLength(1));
      expect(collections.first['name'], equals('Geral'));

      await dbUp.close();
    });
  });

  group('Migrations v4 — document description', () {
    test('documents tem coluna description em fresh install v4', () async {
      final dbV4 = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 4,
          singleInstance: false,
          onCreate: (db, version) async {
            for (final sql in Migrations.allV4) {
              await db.execute(sql);
            }
          },
        ),
      );

      final info = await dbV4.rawQuery('PRAGMA table_info(documents)');
      final hasDesc = info.any((col) => col['name'] == 'description');
      expect(hasDesc, isTrue);

      await dbV4.close();
    });

    test('upgrade v3 → v4 adiciona coluna description', () async {
      final dbUp = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 3,
          singleInstance: false,
          onCreate: (db, version) async {
            for (final sql in Migrations.allV3) {
              await db.execute(sql);
            }
          },
        ),
      );

      // Antes do upgrade, description não existe
      var info = await dbUp.rawQuery('PRAGMA table_info(documents)');
      expect(info.any((col) => col['name'] == 'description'), isFalse);

      // Aplica upgrade
      for (final sql in Migrations.upgradeV3toV4) {
        await dbUp.execute(sql);
      }

      // Agora existe
      info = await dbUp.rawQuery('PRAGMA table_info(documents)');
      expect(info.any((col) => col['name'] == 'description'), isTrue);

      await dbUp.close();
    });
  });
}
