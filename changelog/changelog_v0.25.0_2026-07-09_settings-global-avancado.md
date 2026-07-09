## [0.25.0] - 2026-07-09

### Adicionado
- **settings_screen.dart**: Toggle "Verificar fidelidade" como configuração global (entre Conhecimento geral e Aparência).
- **settings_screen.dart**: Seção "Avançado" com 3 sliders configuráveis:
  - Mensagens de contexto (5–30, default 10)
  - Chunks por busca (3–20, default 10)
  - Tamanho do chunk (200–1000, default 500)
- **chat_controller.dart**: `maxHistoryMessages` e `maxChunksPerQuery` lidos de SecureStorage com fallback para AppConfig.
- **chat_screen.dart**: `chunkMaxTokens` lido de SecureStorage e passado ao ChunkingService na ingestão.

### Alterado
- **chat_controller.dart**: `_checkAndPromote()` lê toggle de fidelidade de SecureStorage (global) em vez de coluna por coleção.
- **chat_screen.dart**: Dialog "Configurações da coleção" simplificado — toggles movidos para Settings, dialog apenas informa.

### Comportamento
- Todas as configurações de comportamento agora são globais em Settings (não mais por coleção).
- Sliders persistem via Keychain: `max_history_messages`, `max_chunks_per_query`, `chunk_max_tokens`.
- Toggle fidelidade persiste via `verify_before_promote_enabled` (default: true).
- Alteração de `chunk_max_tokens` afeta apenas documentos indexados após a mudança.
