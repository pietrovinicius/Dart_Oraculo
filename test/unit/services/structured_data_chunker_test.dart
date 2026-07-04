import 'package:dart_oraculo/core/services/structured_data_chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StructuredDataChunker chunker;

  setUp(() {
    chunker = StructuredDataChunker();
  });

  group('StructuredDataChunker', () {
    test('agrupa linhas pela coluna configurável', () {
      final rows = [
        {'TABLE_NAME': 'PACIENTE', 'COLUMN_NAME': 'CD_PACIENTE', 'DATA_TYPE': 'NUMBER'},
        {'TABLE_NAME': 'PACIENTE', 'COLUMN_NAME': 'NM_PACIENTE', 'DATA_TYPE': 'VARCHAR2'},
        {'TABLE_NAME': 'PACIENTE', 'COLUMN_NAME': 'DT_NASCIMENTO', 'DATA_TYPE': 'DATE'},
        {'TABLE_NAME': 'MEDICO', 'COLUMN_NAME': 'CD_MEDICO', 'DATA_TYPE': 'NUMBER'},
        {'TABLE_NAME': 'MEDICO', 'COLUMN_NAME': 'NM_MEDICO', 'DATA_TYPE': 'VARCHAR2'},
      ];

      final chunks = chunker.chunkByGroup(
        rows: rows,
        groupByColumn: 'TABLE_NAME',
      );

      expect(chunks, hasLength(2));
    });

    test('todas as linhas do mesmo grupo ficam no mesmo chunk', () {
      final rows = [
        {'TABLE_NAME': 'PACIENTE', 'COLUMN_NAME': 'CD_PACIENTE', 'DATA_TYPE': 'NUMBER'},
        {'TABLE_NAME': 'PACIENTE', 'COLUMN_NAME': 'NM_PACIENTE', 'DATA_TYPE': 'VARCHAR2'},
        {'TABLE_NAME': 'PACIENTE', 'COLUMN_NAME': 'DT_NASCIMENTO', 'DATA_TYPE': 'DATE'},
      ];

      final chunks = chunker.chunkByGroup(
        rows: rows,
        groupByColumn: 'TABLE_NAME',
      );

      expect(chunks, hasLength(1));
      expect(chunks.first.content, contains('CD_PACIENTE'));
      expect(chunks.first.content, contains('NM_PACIENTE'));
      expect(chunks.first.content, contains('DT_NASCIMENTO'));
    });

    test('chunk inclui cabeçalho de contexto em linguagem natural', () {
      final rows = [
        {'TABLE_NAME': 'PACIENTE', 'COLUMN_NAME': 'CD_PACIENTE', 'DATA_TYPE': 'NUMBER'},
      ];

      final chunks = chunker.chunkByGroup(
        rows: rows,
        groupByColumn: 'TABLE_NAME',
      );

      expect(chunks.first.content, contains('Tabela PACIENTE'));
    });

    test('chunk formata dados como tabela markdown', () {
      final rows = [
        {'TABLE_NAME': 'MEDICO', 'COLUMN_NAME': 'CD_MEDICO', 'DATA_TYPE': 'NUMBER'},
        {'TABLE_NAME': 'MEDICO', 'COLUMN_NAME': 'NM_MEDICO', 'DATA_TYPE': 'VARCHAR2'},
      ];

      final chunks = chunker.chunkByGroup(
        rows: rows,
        groupByColumn: 'TABLE_NAME',
      );

      // Tabela markdown tem | como separador
      expect(chunks.first.content, contains('|'));
      expect(chunks.first.content, contains('COLUMN_NAME'));
      expect(chunks.first.content, contains('DATA_TYPE'));
    });

    test('funciona com coluna de agrupamento diferente (object_name)', () {
      final rows = [
        {'NAME': 'FN_CALCULA_IDADE', 'LINE': '1', 'TEXT': 'CREATE FUNCTION'},
        {'NAME': 'FN_CALCULA_IDADE', 'LINE': '2', 'TEXT': 'RETURN NUMBER'},
        {'NAME': 'PKG_UTILS', 'LINE': '1', 'TEXT': 'CREATE PACKAGE'},
      ];

      final chunks = chunker.chunkByGroup(
        rows: rows,
        groupByColumn: 'NAME',
      );

      expect(chunks, hasLength(2));
      expect(chunks[0].content, contains('FN_CALCULA_IDADE'));
      expect(chunks[1].content, contains('PKG_UTILS'));
    });

    test('retorna lista vazia para rows vazio', () {
      final chunks = chunker.chunkByGroup(
        rows: [],
        groupByColumn: 'TABLE_NAME',
      );

      expect(chunks, isEmpty);
    });

    test('lança exceção se coluna de agrupamento não existe', () {
      final rows = [
        {'TABLE_NAME': 'PACIENTE', 'COLUMN_NAME': 'CD_PACIENTE'},
      ];

      expect(
        () => chunker.chunkByGroup(
          rows: rows,
          groupByColumn: 'COLUNA_INEXISTENTE',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
