## [0.32.0] - 2026-07-15

### Adicionado
- **ErrorFeedbackService** (`lib/core/services/error_feedback_service.dart`): serviço centralizado para feedback visual de erros ao usuário. Três métodos estáticos:
  - `showError(context, title, message)`: SnackBar vermelho com `AppColors.error`.
  - `showWarning(context, message)`: SnackBar laranja.
  - `showCriticalError(context, message)`: AlertDialog modal não-dismissível com título "Erro Crítico".
- **Testes** (`test/unit/services/error_feedback_service_test.dart`): dois `testWidgets` cobrindo `showError` (SnackBar com texto formatado "title: message") e `showCriticalError` (AlertDialog com título "Erro Crítico").