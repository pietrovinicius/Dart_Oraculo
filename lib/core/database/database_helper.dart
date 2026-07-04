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
    for (final sql in Migrations.allV2) {
      await db.execute(sql);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final sql in Migrations.upgradeV1toV2) {
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
