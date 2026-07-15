## [0.32.0] - 2026-07-15

### Alterado
- **lib/core/models/auth_result.dart**: novo modelo AuthResult com `success` bool + `message` opcional, substituindo o enum sem diagnóstico.
- **lib/features/auth/auth_service.dart**: authenticate() agora retorna AuthResult com mensagens localizadas por código de PlatformException (LockedOut, NotAvailable, NotEnrolled, UserCanceled).
- **lib/features/auth/lock_screen.dart**: usa ErrorFeedbackService.showError() para exibir mensagem de falha ao usuário via SnackBar.
