## [0.22.0] - 2026-07-08

### Adicionado
- **web_search_service.dart**: Busca na internet via Brave Search API (até 5 resultados, timeout 10s).
- **chat_controller.dart**: Fallback web automático quando FTS5 retorna 0 chunks + toggle ligado + motor Claude.
- **chat_controller.dart**: Contexto web injetado no prompt com título, URL e snippet de cada resultado.
- **anthropic_service.dart**: Instrução #7 no prompt: "cite URL fonte do CONTEXTO WEB".
- **settings_screen.dart**: Campo Brave Search API key (Keychain) + instruções.
- **migrations.dart**: Migration v9 — coluna `web_search_fallback` em collections (default 0).

### Comportamento
- RAG vazio + motor Claude + toggle ligado + Brave key → busca web automática.
- Qwen local: nunca aciona web search.
- Toggle desligado por default (opt-in por coleção).
- Badge "🌐 Fonte: internet" pendente para próxima iteração visual.
