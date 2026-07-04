## [0.8.2] - 2026-07-03

### Corrigido
- **lib/core/services/secure_storage_service.dart**: erro -34018 do Keychain ("A required entitlement isn't present") corrigido com `MacOsOptions(useDataProtectionKeyChain: false)`. Keychain legado funciona sem code signing em dev. Adicionado fallback automático para arquivo JSON local (.secure_store.json) caso Keychain falhe.
- **lib/features/settings/settings_screen.dart**: botão salvar API key agora valida chave vazia e envolve em try/catch com SnackBar de erro.
- **macos/Runner/DebugProfile.entitlements**: sandbox desabilitado para debug + adicionado `network.client` para chamadas HTTP.
- **macos/Runner/Release.entitlements**: adicionado `network.client`.

### Adicionado
- **lib/core/services/logger_service.dart**: logger centralizado com output em console (debugPrint) e arquivo log.txt em Application Support.
- Logging em todos os fluxos: SecureStorage, AuthService, SettingsController, DocumentService, ChatController.
- **Anotacoes.txt**: instruções completas de setup macOS e Windows.
- **run_macos.sh**: script de execução para macOS.
- **run_windows.bat**: script de execução para Windows.
