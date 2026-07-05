import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() => sqfliteFfiInit());

  group('Migration v7', () {
    test('fresh install v7 inclui verify_before_promote em collections', () async {
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

      final info = await db.rawQuery('PRAGMA table_info(collections)');
      final cols = info.map((r) => r['name'] as String).toList();
      expect(cols, contains('verify_before_promote'));

      await db.close();
    });

    test('upgrade v6→v7 adiciona coluna com default 1', () async {
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

      // Insert collection antes do upgrade
      await db.insert('collections', {
        'name': 'Test',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Upgrade
      for (final sql in Migrations.upgradeV6toV7) {
        await db.execute(sql);
      }

      // Verifica default
      final rows = await db.query('collections');
      expect(rows.first['verify_before_promote'], 1);

      await db.close();
    });
  });
}
