## [0.14.0] - 2026-07-04

### Adicionado
- **lib/core/services/generation_service.dart**: propriedade `maxContextCharsPerChunk` na interface — cada motor declara seu próprio limite (Anthropic: 20000, Ollama: 4000).
- **lib/features/chat/chat_controller.dart**: truncagem de chunks grandes no prompt com nota explicativa ("conteúdo truncado, total N linhas"). Chunk armazenado e indexado permanece íntegro.
- **lib/features/documents/document_service.dart**:
  - `_parseJsonInIsolate()`: parsing via `compute()` para JSON > 5MB (não bloqueia UI)
  - `_persistDocumentBatch()`: inserções em lote via `db.transaction` por batch de 1000 chunks
  - Progresso granular: 0.0 → 0.3 (parsing) → 0.5 (chunking) → 0.5-1.0 (persist por batch)
- **AGENTS.md**: ADR-016 documenta diferença intencional de limites — cloud prioriza completude, local prioriza velocidade.
- **test/unit/features/chat/chat_controller_test.dart**: 2 novos testes (chunk grande permanece íntegro no banco mas truncado no prompt; chunk pequeno passa inteiro).
- **test/unit/features/documents/document_service_test.dart**: 2 novos testes (batch insert com 1500 rows; progresso monotonicamente crescente).

### Nota de design
- **Limite por motor, não global**: Sonnet/Opus recebem até 20000 chars/chunk (tabela CPOE_MATERIAL com 481 colunas passa quase inteira). Qwen local recebe até 4000 chars/chunk (~50 colunas) para manter inferência rápida.
- **Truncagem no prompt, não na indexação**: FTS5 indexa o chunk completo (busca encontra qualquer coluna). Só o contexto enviado ao modelo é limitado.
- **Veredito para tabelas_e_colunas.json (134MB)**: com estas mudanças, pode ser carregado. Isolate evita congelamento de UI; batch transactions reduzem persist de 60s para 5s; progresso granular informa o usuário.
