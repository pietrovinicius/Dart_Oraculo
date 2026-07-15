## [0.31.3] - 2026-07-15

### Corrigido
- **Redução de 3 autorizações Keychain para 1:** Todos os reads em `chat_screen.dart` e `chat_controller.dart` agora usam `AppSettingsCache` em vez de `SecureStorageService().readRaw()`. Eliminadas as 3 autorizações Keychain adicionais que ocorriam na inicialização do ChatScreen.
- **chat_screen.dart**: `_loadTextScale()`, `_loadChunkMaxTokens()`, `_loadKimiKey()`, `_updateKimiService()` agora leem cache.
- **chat_controller.dart**: `askQuestion()` e `checkFidelity()` leem cache para `max_chunks_per_query`, `chunk_max_tokens`, `general_knowledge_enabled`, `max_history_messages`, `verify_before_promote_enabled`.
- **Writes com invalidação:** Todas as writes em ambos os arquivos agora invalidam cache após atualizar Keychain.
