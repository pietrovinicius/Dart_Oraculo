import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('Migration v5', () {
    test('fresh install v5 inclui coluna image_path em messages', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final sql in Migrations.allV5) {
              await db.execute(sql);
            }
          },
        ),
      );

      final info = await db.rawQuery('PRAGMA table_info(messages)');
      final cols = info.map((r) => r['name'] as String).toList();
      expect(cols, contains('image_path'));

      await db.close();
    });

    test('upgrade v4→v5 adiciona coluna image_path', () async {
      final db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            for (final sql in Migrations.allV4) {
              await db.execute(sql);
            }
          },
        ),
      );

      // Simula upgrade
      for (final sql in Migrations.upgradeV4toV5) {
        await db.execute(sql);
      }

      final info = await db.rawQuery('PRAGMA table_info(messages)');
      final cols = info.map((r) => r['name'] as String).toList();
      expect(cols, contains('image_path'));

      await db.close();
    });
  });
}
