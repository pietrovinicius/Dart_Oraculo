import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/services/logger_service.dart';
import 'models/collection.dart';

/// Serviço de CRUD de coleções.
class CollectionService {
  CollectionService({required Database database}) : _db = database;

  static const _tag = 'CollectionService';
  final Database _db;

  /// Lista todas as coleções.
  Future<List<Collection>> listCollections() async {
    final rows = await _db.query('collections', orderBy: 'created_at ASC');
    return rows.map(Collection.fromMap).toList();
  }

  /// Cria uma nova coleção.
  Future<Collection> createCollection({
    required String name,
    String? instructions,
  }) async {
    LoggerService.instance.info(_tag, 'createCollection("$name")');
    final now = DateTime.now();
    final id = await _db.insert('collections', {
      'name': name,
      'instructions': instructions != null && instructions.length > 500
          ? instructions.substring(0, 500)
          : instructions,
      'created_at': now.toIso8601String(),
    });
    return Collection(id: id, name: name, instructions: instructions, createdAt: now);
  }

  /// Retorna uma coleção por ID.
  Future<Collection?> getCollection(int id) async {
    final rows = await _db.query(
      'collections',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Collection.fromMap(rows.first);
  }

  /// Retorna a coleção padrão "Geral".
  Future<Collection> getDefaultCollection() async {
    final rows = await _db.query(
      'collections',
      where: 'name = ?',
      whereArgs: ['Geral'],
      limit: 1,
    );
    if (rows.isNotEmpty) return Collection.fromMap(rows.first);
    // Fallback: cria se não existe
    return createCollection(name: 'Geral');
  }

  /// Deleta uma coleção (não permite deletar "Geral").
  Future<bool> deleteCollection(int id) async {
    final collection = await getCollection(id);
    if (collection == null || collection.name == 'Geral') return false;
    await _db.delete('collections', where: 'id = ?', whereArgs: [id]);
    return true;
  }
}
