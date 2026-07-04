## [0.10.0] - 2026-07-04

### Adicionado
- **lib/core/database/migrations.dart**: tabela `collections` (id, name, instructions, created_at). Colunas `collection_id` em `documents` e `conversations` como FK. Migration v2→v3 com backfill automático (coleção "Geral" criada e dados existentes associados).
- **lib/core/database/database_helper.dart**: `onUpgrade` v2→v3 com backfill — nenhum documento ou conversa fica órfão.
- **lib/core/services/fts_service.dart**: parâmetro `collectionId` no `search()` — JOIN filtra chunks cujo documento pertence àquela coleção. Busca sem `collectionId` permanece global.
- **lib/features/chat/chat_controller.dart**: `askQuestion` aceita `collectionId` (filtro FTS) e `collectionInstructions` (injetado no contexto do prompt antes do RAG). `createConversation` aceita `collectionId`.
- **lib/features/collections/collection_service.dart**: CRUD de coleções — list, create (instrução limitada a 500 chars), getDefault, getCollection, delete (protege "Geral").
- **lib/features/collections/models/collection.dart**: modelo Collection com id, name, instructions, createdAt.
- **lib/features/chat/widgets/sidebar.dart**: seletor de coleção (DropdownButton) no topo da sidebar + botão nova coleção. Lista de conversas e contagem de documentos filtram pela coleção ativa.
- **lib/features/chat/chat_screen.dart**: estado de coleção ativa, filtragem de conversas/documentos, criação de conversa e upload associam à coleção ativa, instructions passado ao chat.
- **lib/features/chat/models/conversation.dart**: campo `collectionId`.
- **lib/features/documents/models/document.dart**: campo `collectionId`.
- **lib/features/documents/document_service.dart**: `ingestPdf`/`ingestMarkdown` aceitam `collectionId`.
- **test/unit/database/migrations_test.dart**: 5 novos testes v3 (tabela collections, colunas, Geral criada, upgrade v2→v3 com backfill).
- **test/unit/services/fts_service_test.dart**: 4 novos testes de busca filtrada por coleção.

### Alterado
- **lib/core/config/app_config.dart**: `databaseVersion` → 3.
