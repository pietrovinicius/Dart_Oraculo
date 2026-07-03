import 'package:dart_oraculo/core/database/migrations.dart';
import 'package:dart_oraculo/core/services/fts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late FtsService ftsService;

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
    ftsService = FtsService(database: db);

    // Seed: 3 documentos com chunks variados
    await db.insert('documents', {
      'filename': 'flutter.pdf',
      'imported_at': DateTime.now().toIso8601String(),
    });
    await db.insert('documents', {
      'filename': 'dart.pdf',
      'imported_at': DateTime.now().toIso8601String(),
    });
    await db.insert('documents', {
      'filename': 'python.pdf',
      'imported_at': DateTime.now().toIso8601String(),
    });

    // Chunks do doc 1 (flutter)
    await db.insert('chunks', {
      'document_id': 1,
      'page': 1,
      'content': 'Flutter é um framework multiplataforma para construir apps nativos.',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('chunks', {
      'document_id': 1,
      'page': 2,
      'content': 'Widgets são os blocos fundamentais da interface em Flutter.',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Chunks do doc 2 (dart)
    await db.insert('chunks', {
      'document_id': 2,
      'page': 1,
      'content': 'Dart é a linguagem de programação usada pelo Flutter.',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('chunks', {
      'document_id': 2,
      'page': 3,
      'content': 'Async await permite código assíncrono legível em Dart.',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Chunks do doc 3 (python)
    await db.insert('chunks', {
      'document_id': 3,
      'page': 1,
      'content': 'Python é uma linguagem interpretada usada em data science.',
      'created_at': DateTime.now().toIso8601String(),
    });
  });

  tearDown(() async {
    await db.close();
  });

  group('FtsService', () {
    test('busca retorna chunks relevantes para termo simples', () async {
      final results = await ftsService.search('Flutter');

      expect(results, isNotEmpty);
      expect(
        results.every((r) =>
            r.content.toLowerCase().contains('flutter')),
        isTrue,
      );
    });

    test('busca retorna resultados ordenados por relevância', () async {
      final results = await ftsService.search('Flutter framework');

      expect(results, isNotEmpty);
      // O chunk que contém ambos os termos deve aparecer primeiro
      expect(results.first.content, contains('framework'));
      expect(results.first.content, contains('Flutter'));
    });

    test('busca respeita limite máximo de resultados', () async {
      final results = await ftsService.search('Flutter', limit: 2);

      expect(results.length, lessThanOrEqualTo(2));
    });

    test('busca retorna vazio para termo sem match', () async {
      final results = await ftsService.search('javascript react angular');

      expect(results, isEmpty);
    });

    test('resultado inclui metadados do chunk (id, documentId, page)', () async {
      final results = await ftsService.search('Python');

      expect(results, hasLength(1));
      expect(results.first.chunkId, isNotNull);
      expect(results.first.documentId, equals(3));
      expect(results.first.page, equals(1));
    });

    test('resultado inclui nome do arquivo do documento', () async {
      final results = await ftsService.search('Dart linguagem');

      expect(results, isNotEmpty);
      expect(results.first.filename, equals('dart.pdf'));
    });

    test('busca com múltiplos termos encontra matches parciais', () async {
      final results = await ftsService.search('async Dart');

      expect(results, isNotEmpty);
      expect(
        results.any((r) => r.content.contains('Async')),
        isTrue,
      );
    });

    test('busca ignora query vazia', () async {
      final results = await ftsService.search('');
      expect(results, isEmpty);

      final resultsSpaces = await ftsService.search('   ');
      expect(resultsSpaces, isEmpty);
    });
  });
}
