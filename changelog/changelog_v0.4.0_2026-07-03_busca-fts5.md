## [0.4.0] - 2026-07-03

### Adicionado
- **lib/core/services/fts_service.dart**: busca de texto completo via FTS5 com ranking BM25. Sanitiza query (remove operadores FTS5), usa OR para matches parciais flexíveis, JOIN com documents para retornar filename. Retorna FtsResult com chunkId, documentId, filename, page, content e rank.
- **test/unit/services/fts_service_test.dart**: 8 testes cobrindo busca simples, ordenação por relevância, limite de resultados, termo sem match, metadados completos, nome de arquivo, multi-termo e query vazia.
