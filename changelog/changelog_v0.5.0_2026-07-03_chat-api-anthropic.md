## [0.5.0] - 2026-07-03

### Adicionado
- **lib/core/services/anthropic_service.dart**: cliente HTTP direto para api.anthropic.com/v1/messages com streaming SSE. Monta request body com system prompt (contexto RAG), histórico e pergunta. Parseia eventos SSE extraindo text_delta. Lança AnthropicException tipada em erros HTTP.
- **lib/features/chat/chat_controller.dart**: controller principal do chat — orquestra pergunta → busca FTS5 → montagem de contexto → chamada API com streaming → persistência de user + assistant no banco. Inclui histórico recente limitado a 10 mensagens. Armazena chunks_used em JSON para rastreabilidade de citação.
- **lib/features/chat/models/conversation.dart**: modelo Conversation com toMap/fromMap.
- **lib/features/chat/models/message.dart**: modelo Message com toMap/fromMap, inclui chunksUsed para citação.
- **test/unit/services/anthropic_service_test.dart**: 9 testes (buildRequestBody, system prompt, histórico, parseStreamEvent, headers, sendMessage streaming, erro HTTP).
- **test/unit/features/chat/chat_controller_test.dart**: 6 testes (createConversation, listConversations, askQuestion com persistência, chunks_used, histórico, deleteConversation).
