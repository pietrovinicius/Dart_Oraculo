## [0.12.0] - 2026-07-04

### Adicionado
- **lib/core/services/structured_data_chunker.dart**: chunker alternativo para dados estruturados. Agrupa linhas por valor de coluna configurável, produz um chunk por grupo formatado como tabela markdown, precedido de cabeçalho em linguagem natural ("Tabela PACIENTE, colunas:"). Lança ArgumentError se coluna não existe.
- **lib/features/documents/document_service.dart**: `ingestStructuredData(bytes, filename, groupByColumn)` — detecta .csv ou .json pela extensão, parseia (csv via pacote `csv`, json via `dart:convert`), chama structured_data_chunker, persiste em documents/chunks com collection_id.
- **lib/features/chat/chat_screen.dart**: file_picker aceita `.csv` e `.json`. Ao importar dados estruturados, dialog mostra colunas detectadas para o usuário selecionar qual é a coluna de agrupamento. Sem seleção, cancela o upload daquele arquivo.
- **pubspec.yaml**: dependência `csv: ^6.0.0`.
- **test/unit/services/structured_data_chunker_test.dart**: 7 testes (agrupamento por coluna, linhas no mesmo chunk, cabeçalho natural, formato markdown, coluna alternativa, vazio, coluna inexistente).
- **test/unit/features/documents/document_service_test.dart**: 3 novos testes (CSV agrupado, JSON agrupado, FTS5 indexado para dados estruturados).

### Nota de design
- Coluna de agrupamento é informada manualmente pelo usuário no momento do upload (dialog com auto-detect), não assumida pelo tipo de arquivo. Isso permite o mesmo formato .csv para ALL_TAB_COLUMNS (TABLE_NAME), ALL_SOURCE (NAME) e ALL_TRIGGERS (TRIGGER_NAME).
