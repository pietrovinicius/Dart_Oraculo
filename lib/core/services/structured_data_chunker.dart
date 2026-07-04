import '../services/chunking_service.dart';

/// Chunker para dados estruturados (CSV/JSON).
/// Agrupa linhas por valor de uma coluna configurável,
/// produzindo um chunk por grupo com formato de tabela markdown.
class StructuredDataChunker {
  /// Agrupa [rows] pela coluna [groupByColumn] e retorna um [TextChunk]
  /// por valor distinto, com todas as linhas daquele grupo formatadas
  /// como tabela markdown, precedidas de contexto em linguagem natural.
  ///
  /// Lança [ArgumentError] se [groupByColumn] não existir nas rows.
  List<TextChunk> chunkByGroup({
    required List<Map<String, dynamic>> rows,
    required String groupByColumn,
  }) {
    if (rows.isEmpty) return [];

    // Valida que a coluna existe
    if (!rows.first.containsKey(groupByColumn)) {
      throw ArgumentError(
        'Coluna "$groupByColumn" não encontrada. '
        'Colunas disponíveis: ${rows.first.keys.join(", ")}',
      );
    }

    // Agrupa por valor da coluna
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final key = (row[groupByColumn] ?? '').toString();
      groups.putIfAbsent(key, () => []).add(row);
    }

    // Gera um chunk por grupo
    return groups.entries.map((entry) {
      final groupName = entry.key;
      final groupRows = entry.value;

      // Colunas do grupo (excluindo a coluna de agrupamento)
      final allColumns = groupRows.first.keys
          .where((col) => col != groupByColumn)
          .toList();

      // Cabeçalho de contexto em linguagem natural
      final header = 'Tabela $groupName, colunas:';

      // Tabela markdown
      final buffer = StringBuffer();
      buffer.writeln(header);
      buffer.writeln();

      // Header da tabela
      buffer.writeln('| ${allColumns.join(' | ')} |');
      buffer.writeln('| ${allColumns.map((_) => '---').join(' | ')} |');

      // Linhas
      for (final row in groupRows) {
        final values = allColumns.map((col) => (row[col] ?? '').toString());
        buffer.writeln('| ${values.join(' | ')} |');
      }

      return TextChunk(page: 0, content: buffer.toString().trim());
    }).toList();
  }
}
