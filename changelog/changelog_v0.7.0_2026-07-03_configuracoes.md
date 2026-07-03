## [0.7.0] - 2026-07-03

### Adicionado
- **lib/features/settings/settings_controller.dart**: controller com load, saveApiKey, saveModel, saveBiometric, deleteApiKey. Persiste tudo via SecureStorageService e notifica listeners.
- **lib/features/settings/settings_screen.dart**: tela completa — campo de API key mascarado com botão salvar, seleção de modelo (Sonnet 5 / Opus 4.8) com ícone de radio, switch para exigir biometria ao abrir. Feedback via SnackBar.
- **test/widget/settings_screen_test.dart**: 7 testes unitários do SettingsController (valores padrão, persistência, delete, reload, notificações).
