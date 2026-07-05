import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('Migration v8', () {
    test('fresh install v8 inclui conversation_context_attachments', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, _) async {
            for (final sql in Migrations.allV8) {
              await db.execute(sql);
            }
          },
        ),
      );

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='conversation_context_attachments'",
      );
      expect(tables, hasLength(1));

      await db.close();
    });

    test('upgrade v7→v8 cria tabela', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, _) async {
            for (final sql in Migrations.allV7) {
              await db.execute(sql);
            }
          },
        ),
      );

      for (final sql in Migrations.upgradeV7toV8) {
        await db.execute(sql);
      }

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='conversation_context_attachments'",
      );
      expect(tables, hasLength(1));

      await db.close();
    });
  });
}
