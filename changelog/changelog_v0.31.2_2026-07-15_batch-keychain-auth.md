## [0.31.2] - 2026-07-15

### Corrigido
- **Keychain batch read:** Implementado `AppSettingsCache` — carrega todas as chaves do Keychain em 1 autorização (antes: 7+ prompts sequenciais). `main.dart` faz batch read em paralelo na inicialização, cache em memória. Todos os consumers (ThemeNotifier, SettingsController, SettingsScreen, ChatController) leem do cache, não do Keychain diretamente.
- **secure_storage_service.dart**: Reversão — mantém `useDataProtectionKeyChain: false` (app sem sandbox), singleton inalterado.
- **settings_controller.dart**: `load()` agora síncrono do cache; fallback ao storage para testes.
- **theme_notifier.dart**: Lê cache sem passar `SecureStorageService` ao construtor.
- **settings_screen.dart**: Todos os `_storage` removidos; usa `AppSettingsCache` para reads, `SecureStorageService()` para writes com `invalidate()` subsequente.
