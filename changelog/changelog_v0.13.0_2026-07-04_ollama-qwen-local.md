## [0.13.0] - 2026-07-04

### Adicionado
- **lib/core/services/generation_service.dart**: interface abstrata `GenerationService` com `streamResponse()` e `modelDisplayName`. Permite trocar motor de geração por injeção de dependência.
- **lib/core/services/ollama_service.dart**: motor local via Ollama (http://localhost:11434/api/chat). Modelo `qwen3.5:latest`. Valida disponibilidade antes de cada chamada. Rejeita modelos `:cloud` (execução remota). Parseia streaming JSON-per-line. Mensagem de erro clara se Ollama não está rodando ou modelo não foi baixado.
- **lib/core/services/anthropic_service.dart**: agora implementa `GenerationService`. Aceita `model` no construtor.
- **lib/features/chat/chat_controller.dart**: campo `activeGenerationService` — quando setado, usa implementação alternativa (Ollama) em vez da Anthropic. FTS5/persistência/citações inalterados.
- **lib/features/chat/chat_screen.dart**: seletor de modelo com 3 opções (Sonnet, Opus, Qwen Local). Troca `activeGenerationService` no controller ao mudar seleção. Inicializa baseado no modelo padrão salvo.
- **lib/features/settings/settings_screen.dart**: opção "Qwen (Local) — Offline via Ollama, sem custo de API" no seletor de modelo padrão.
- **lib/core/config/app_config.dart**: `modelQwen`, `ollamaBaseUrl`, `ollamaModel`. `appVersion` → 0.13.0.
- **test/unit/services/ollama_service_test.dart**: 5 testes — rejeição :cloud, aceita modelo válido, erro quando serviço não responde, erro quando modelo não disponível, parsing de streaming correto.

### Nota de design
- A interface `GenerationService` desacopla geração do controller. Qualquer novo motor (Gemini, local LLM, etc) implementa a mesma interface e é injetado sem tocar no controller.
- Checagem de `:cloud` impede acidentalmente usar execução remota da Ollama, mantendo a promessa de funcionamento offline.
- Nenhuma tentativa de reconexão automática — erro aparece imediatamente ao usuário.
