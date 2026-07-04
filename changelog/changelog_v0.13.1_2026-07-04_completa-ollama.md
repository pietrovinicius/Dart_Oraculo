## [0.13.1] - 2026-07-04

### Corrigido
- **lib/features/documents/document_service.dart**: `_generateDescription()` agora usa `GenerationService` via injeção (pode ser Anthropic ou Ollama). Quando Qwen é o padrão configurado, descrição é gerada localmente via Ollama. **Status: feito.**
- **lib/features/chat/chat_controller.dart**: campo `model_used` na mensagem persistida agora grava `modelDisplayName` do `GenerationService` ativo — exibe "Qwen (Local)" ou "claude-sonnet-4-6" corretamente no message_bubble. **Status: feito.**

### Confirmado (já existia, sem alteração necessária)
- **instructions da coleção com Qwen**: o campo `collectionInstructions` é injetado no contexto (linha 107 do controller) ANTES da escolha de motor. Funciona identicamente para Anthropic e Ollama. **Status: já existente.**

### Refatorado
- **lib/features/chat/chat_controller.dart**: arquitetura de injeção pura. `activeGenerationService` é `late`-init com default `_anthropicService`, nunca null. **Não existe condicional** — o controller sempre chama `activeGenerationService.streamResponse()`. A decisão de qual implementação usar é feita externamente pelo `chat_screen` via setter. **Status: injeção pura, sem condicional.**
- **lib/features/documents/document_service.dart**: removido `_defaultModel` — agora resolve motor via `_generationService ?? _anthropicService`, ambos injetados no construtor.

### Adicionado
- **test/unit/features/chat/chat_controller_test.dart**: 1 novo teste — troca de `activeGenerationService` não altera FTS5 nem `chunks_used`, apenas muda `model_used` na resposta.
- **test/widget/settings_screen_test.dart**: 1 novo teste — Qwen (Local) como modelo padrão persiste e é relido corretamente.
- Total: **143 testes passando**.

### Nota técnica
- **Padrão de injeção**: `ChatController` recebe `AnthropicService` no construtor (para sendMessage legado nos testes). O campo `activeGenerationService` é o ponto de extensão — setado pelo chat_screen para `OllamaService()` ou `anthropicService` conforme a seleção do usuário. Nenhum `if` dentro do controller decide qual usar.
