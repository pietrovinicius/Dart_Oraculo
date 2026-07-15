## [0.34.0] - 2026-07-15

### Corrigido
- **document_service.dart**: `reindexCollection2()` agora retorna `Map<String, dynamic>` com contagem de sucesso/falha e lista de documentos que falharam, ao invés de silenciar erros parciais.
- **settings_screen.dart**: caller usa `ErrorFeedbackService` para exibir feedback de re-indexação parcial ao usuário.
