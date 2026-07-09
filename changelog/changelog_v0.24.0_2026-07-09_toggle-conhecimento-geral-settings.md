## [0.24.0] - 2026-07-09

### Alterado
- **settings_screen.dart**: Toggle "Conhecimento geral" adicionado como configuração global do app (seção entre Modelo e Aparência).
- **chat_controller.dart**: Lê toggle de conhecimento geral via `SecureStorageService` (config global) em vez de coluna por coleção.
- **chat_screen.dart**: Toggle de conhecimento geral removido do dialog "Configurações da coleção" — agora é exclusivamente global em Settings.

### Comportamento
- Toggle OFF (padrão): modelo responde somente com base nos documentos indexados (RAG estrito).
- Toggle ON: quando RAG não encontra contexto, modelo responde com conhecimento próprio (Opus/Sonnet).
- Configuração persiste via Keychain (`general_knowledge_enabled`).
