## [0.20.0] - 2026-07-05

### Adicionado
- **migrations.dart**: Migration v8 — tabela `conversation_context_attachments` para documentos de trabalho por conversa.
- **chat_controller.dart**: Métodos `addContextAttachment`, `getContextAttachments`, `removeContextAttachment`.
- **chat_controller.dart**: Injeção automática de documentos de trabalho no prompt (rotulados, truncados se excedem limite do motor).
- **anthropic_service.dart**: Instrução #6 no prompt: "cite nome do DOCUMENTO DE TRABALHO quando usar informação dele".
- **context_attachment_test.dart**: 3 testes unitários (injeção, truncagem, ausência após remoção).
- **migration_v8_test.dart**: 2 testes (fresh install, upgrade).

### Nota
- Diálogo de destino (.md) e indicador visual no cabeçalho serão implementados na UI em seguida.
