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
        version: 4,
        singleInstance: false,
        onCreate: (db, version) async {
          for (final sql in Migrations.allV8) {
            await db.execute(sql);
          }
        },
      ),
    );
    ftsService = FtsService(database: db);

    // Seed: 2 coleções
    await db.insert('collections', {
      'name': 'Dev',
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('collections', {
      'name': 'Data',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Seed: 3 documentos com chunks variados
    await db.insert('documents', {
      'filename': 'flutter.pdf',
      'collection_id': 1,
      'imported_at': DateTime.now().toIso8601String(),
    });
    await db.insert('documents', {
      'filename': 'dart.pdf',
      'collection_id': 1,
      'imported_at': DateTime.now().toIso8601String(),
    });
    await db.insert('documents', {
      'filename': 'python.pdf',
      'collection_id': 2,
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

    test('busca filtrada por collectionId retorna só chunks daquela coleção', () async {
      // Coleção 1 (Dev) tem flutter e dart
      final devResults = await ftsService.search('linguagem', collectionId: 1);
      expect(devResults, isNotEmpty);
      expect(devResults.every((r) => r.documentId <= 2), isTrue);
    });

    test('busca filtrada não retorna chunks de outra coleção', () async {
      // Python está na coleção 2 (Data)
      final devResults = await ftsService.search('Python', collectionId: 1);
      expect(devResults, isEmpty);
    });

    test('busca filtrada pela coleção 2 retorna Python', () async {
      final dataResults = await ftsService.search('Python', collectionId: 2);
      expect(dataResults, hasLength(1));
      expect(dataResults.first.filename, equals('python.pdf'));
    });

    test('busca sem collectionId retorna de todas as coleções', () async {
      final allResults = await ftsService.search('linguagem');
      expect(allResults.length, greaterThanOrEqualTo(2));
    });

    test('stopwords são removidas — "o que é Flutter" busca só Flutter', () async {
      final results = await ftsService.search('o que é o Flutter');
      expect(results, isNotEmpty);
      expect(results.first.content.toLowerCase(), contains('flutter'));
    });

    test('query só com stopwords retorna vazio', () async {
      final results = await ftsService.search('o que é da');
      expect(results, isEmpty);
    });

    test('underscore preservado como termo — busca ADEP_V', () async {
      // Seed chunk com ADEP_V
      await db.insert('chunks', {
        'document_id': 1,
        'page': 5,
        'content': 'A view ADEP_V contém dados de adequação de procedimentos.',
        'created_at': DateTime.now().toIso8601String(),
      });

      final results = await ftsService.search('ADEP_V');
      expect(results, isNotEmpty);
      expect(results.first.content, contains('ADEP_V'));
    });

    test('AND implícito com fallback OR — retorna resultados quando AND falha', () async {
      // "Flutter data" → AND retorna vazio (nenhum chunk tem ambos)
      // Fallback OR retorna chunks com "Flutter" OU "data"
      final results = await ftsService.search('Flutter data');
      expect(results, isNotEmpty);
      // Deve conter pelo menos um chunk com Flutter ou data
      expect(
        results.any((r) =>
            r.content.toLowerCase().contains('flutter') ||
            r.content.toLowerCase().contains('data')),
        isTrue,
      );
    });
  });
}
