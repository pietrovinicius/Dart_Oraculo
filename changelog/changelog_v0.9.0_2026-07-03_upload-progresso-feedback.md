## [0.9.0] - 2026-07-03

### Adicionado
- **lib/features/chat/chat_screen.dart**: upload múltiplo (allowMultiple=true) com validação de máximo 10 arquivos. Barra de progresso determinada (LinearProgressIndicator com value 0..1) + label "Processando X de Y: nome.ext". Resumo de lote ao final (sucesso/falha parcial). Mapa de feedbacks por conversa.
- **lib/features/chat/widgets/message_bubble.dart**: botões de like/dislike (thumb_up/thumb_down) em respostas do assistant, mutuamente exclusivos, com toggle off ao clicar no mesmo ícone novamente.
- **lib/core/database/migrations.dart**: tabela `message_feedback` (id, message_id FK, value CHECK 'like'/'dislike', created_at). Lista `upgradeV1toV2` e `allV2` para fresh install.
- **lib/core/database/database_helper.dart**: handler `onUpgrade` para migrar v1→v2 (adiciona message_feedback).
- **lib/features/chat/chat_controller.dart**: `setFeedback(messageId, value)` — grava, alterna (like↔dislike), ou remove (null/toggle). `getFeedback(messageId)` e `getFeedbacksForConversation(conversationId)` para carregar estado.
- **lib/core/services/pdf_service.dart**: callback opcional `onProgress(int current, int total)` chamado após cada página extraída, com yield ao framework via `Future.delayed(Duration.zero)`.
- **lib/features/documents/document_service.dart**: `onProgress(double)` propagado de pdf_service (fração por página) e markdown (instantâneo 1.0).
- **test/unit/database/migrations_test.dart**: 5 novos testes v2 (cria tabela, insere like, insere dislike, rejeita inválido, upgrade v1→v2).
- **test/unit/features/chat/chat_controller_test.dart**: 6 novos testes de feedback (grava like, grava dislike, alterna, remove com null, toggle off, retorna null sem feedback).
- **test/unit/services/pdf_service_test.dart**: 2 novos testes (onProgress chamado por página, onProgress null ok).

### Alterado
- **lib/core/config/app_config.dart**: `databaseVersion` → 2.
- **database_helper.dart**: `onCreate` usa `allV2` (fresh install já inclui message_feedback).
