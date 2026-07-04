## [0.11.0] - 2026-07-04

### Adicionado
- **lib/core/database/migrations.dart**: coluna `description` (TEXT, nullable) em documents. Migration v3→v4 via ALTER TABLE.
- **lib/features/documents/document_service.dart**: `_generateDescription()` — chama Sonnet com primeiros 3 chunks como entrada, grava descrição de 1-2 frases no momento da ingestão (única vez, cacheada). `exportAsMarkdown(documentId)` — concatena chunks com `\n\n` na ordem de criação, salva em Application Support/exports/.
- **lib/features/documents/library_screen.dart**: tela completa de biblioteca — lista documentos da coleção ativa em cards com filename, tipo (PDF/Markdown), data/hora, descrição AI, e botão "Extrair .md" que exporta e oferece file picker para salvar.
- **lib/features/chat/widgets/sidebar.dart**: tap em "Documentos (N)" navega à LibraryScreen; botão "+" continua fazendo upload.
- **lib/features/documents/models/document.dart**: campo `description`.
- **test/unit/database/migrations_test.dart**: 2 novos testes v4 (coluna description em fresh install e upgrade v3→v4).
- **test/unit/features/documents/document_service_test.dart**: 2 novos testes exportAsMarkdown (concatenação com `\n\n`, ordem correta de chunks).

### Alterado
- **lib/core/config/app_config.dart**: `databaseVersion` → 4.
- **lib/core/database/database_helper.dart**: `onCreate` usa `allV4`; `onUpgrade` inclui v3→v4.
- **lib/features/chat/chat_screen.dart**: passa `AnthropicService` ao `DocumentService` para geração de descrição.
