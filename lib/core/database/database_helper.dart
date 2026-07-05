import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config/app_config.dart';
import 'migrations.dart';

/// Singleton de acesso ao banco SQLite via sqflite_common_ffi.
class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    sqfliteFfiInit();
    final databaseFactory = databaseFactoryFfi;

    final Directory appDir = await getApplicationSupportDirectory();
    final String dbPath = p.join(appDir.path, AppConfig.databaseName);

    return databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppConfig.databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    for (final sql in Migrations.allV5) {
      await db.execute(sql);
    }
    // Fresh install: cria coleção "Geral" padrão
    await db.insert('collections', {
      'name': 'Geral',
      'instructions': null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final sql in Migrations.upgradeV1toV2) {
        await db.execute(sql);
      }
    }
    if (oldVersion < 3) {
      // Cria tabela + colunas
      for (final sql in Migrations.upgradeV2toV3Schema) {
        await db.execute(sql);
      }
      // Backfill: cria coleção "Geral" e associa dados existentes
      final geralId = await db.insert('collections', {
        'name': 'Geral',
        'instructions': null,
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.execute(
        'UPDATE documents SET collection_id = ? WHERE collection_id IS NULL',
        [geralId],
      );
      await db.execute(
        'UPDATE conversations SET collection_id = ? WHERE collection_id IS NULL',
        [geralId],
      );
    }
    if (oldVersion < 4) {
      for (final sql in Migrations.upgradeV3toV4) {
        await db.execute(sql);
      }
    }
    if (oldVersion < 5) {
      for (final sql in Migrations.upgradeV4toV5) {
        await db.execute(sql);
      }
    }
  }

  /// Fecha a conexão. Usado em testes.
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
