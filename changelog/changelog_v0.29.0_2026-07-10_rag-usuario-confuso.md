## [0.29.0] - 2026-07-10

### Adicionado
- **query_reformatter_service.dart**: Novo serviço que reformula queries confusas do usuário via LLM (Haiku) antes do FTS5. Timeout 2s, cache 1h, fallback para query original. Toggle "Reformulação inteligente" em Settings.
- **chat_controller.dart**: Integração do QueryReformatterService — query reformulada antes de buscar FTS5.
- **chat_controller.dart**: Auto-retry — se FTS5 retorna 0 chunks, tenta novamente com top 2 termos da query reformulada.
- **fts_service.dart**: Fuzzy prefix matching expandido — fallback trunca cada termo a 4 chars + wildcard ("dirr*" → encontra "diarreia").
- **fts_service.dart**: Re-ranking heurístico — filtra chunks de metadados/schema (VARCHAR, INTEGER, NOT NULL etc.) com rank ruim. Evita noise técnico nos resultados.
- **docs/PLANO_RAG_USUARIO_CONFUSO.md**: Plano completo com 6 soluções para RAG com usuário confuso.
- **test/unit/services/query_reformatter_service_test.dart**: 7 testes (reformulação, toggle, timeout, cache, fallback).

### Corrigido
- **chat_controller.dart**: `SecureStorageService` agora injetável — resolve falha em testes sem Flutter bindings.
- **test/**: Todos os testes de ChatController atualizados para usar Migrations.allV10 + SecureStorageService com testStore.

### Comportamento
- Query confusa "pesquisa entao diarreia" → reformulada para "diarreia" antes do FTS5.
- Typo "dirreia" → fuzzy prefix "dir*" → encontra "diarreia".
- Chunks de schema (attributes.csv) com 4+ padrões de metadados + rank ruim → removidos do resultado.
- 0 resultados → auto-retry com top 2 termos (transparente ao usuário).
