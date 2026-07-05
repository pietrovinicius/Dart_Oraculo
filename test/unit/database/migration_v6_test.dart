import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('Migration v6', () {
    test('fresh install v6 inclui source_type e original_message_id', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, _) async {
            for (final sql in Migrations.allV6) {
              await db.execute(sql);
            }
          },
        ),
      );

      final info = await db.rawQuery('PRAGMA table_info(chunks)');
      final cols = info.map((r) => r['name'] as String).toList();
      expect(cols, contains('source_type'));
      expect(cols, contains('original_message_id'));

      await db.close();
    });

    test('upgrade v5→v6 adiciona colunas com default document', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (db, _) async {
            for (final sql in Migrations.allV5) {
              await db.execute(sql);
            }
          },
        ),
      );

      // Insert chunk antes do upgrade
      await db.insert('documents', {
        'filename': 'test.pdf',
        'imported_at': DateTime.now().toIso8601String(),
      });
      await db.insert('chunks', {
        'document_id': 1,
        'page': 1,
        'content': 'teste',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Upgrade
      for (final sql in Migrations.upgradeV5toV6) {
        await db.execute(sql);
      }

      // Verifica default
      final rows = await db.query('chunks');
      expect(rows.first['source_type'], 'document');
      expect(rows.first['original_message_id'], isNull);

      await db.close();
    });
  });
}
