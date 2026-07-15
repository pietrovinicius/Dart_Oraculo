## [0.31.0] - 2026-07-15

### Corrigido
- **lib/core/theme/theme_notifier.dart**: Eliminado `catch (_) {}` silencioso em `setMode()` que causava perda de dados quando a escrita no Keychain falhava. Agora reverte o estado do tema e exibe AlertDialog crítico ao usuário se contexto for fornecido.
- **lib/features/settings/settings_screen.dart**: Callers de `setMode()` agora passam `context` para permitir feedback de erro visual.
- **Novo**: Adicionado teste unitário (`test/unit/core/theme/theme_notifier_test.dart`) que verifica: (1) sucesso em escrita, (2) revert de estado em falha sem contexto, (3) diálogo de erro crítico com contexto.
