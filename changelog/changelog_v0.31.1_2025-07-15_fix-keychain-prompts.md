## [0.31.1] - 2025-07-15

### Corrigido
- **secure_storage_service.dart**: SecureStorageService transformado em singleton — elimina prompts repetidos do Keychain ao abrir o app. Alterado `useDataProtectionKeyChain` de `false` para `true` (data protection keychain desbloqueia uma vez no login do macOS, não por item).
- **fake_secure_storage.dart**: Testes atualizados para usar construtor `.test()` separado do singleton.
