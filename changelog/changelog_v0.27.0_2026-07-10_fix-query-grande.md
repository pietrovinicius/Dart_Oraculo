## [0.27.0] - 2026-07-10

### Corrigido
- **fts_service.dart**: `_sanitizeQuery` agora limita a 8 termos máximo — evita queries FTS5 explosivas com textos longos colados.
- **fts_service.dart**: `_extractNaturalLanguage` ignora linhas SQL (SELECT/FROM/WHERE etc.) e busca apenas o texto natural da pergunta.
- **chat_screen.dart**: blocos `catch` agora capturam `e.message`/`e.toString()` e passam para `_lastError` — erro detalhado visível na UI.
- **retry_bubble.dart**: exibe `errorMessage` como subtitle (truncada a 120 chars) em vez de genérico "Falha ao gerar resposta".
- **chat_input.dart**: indicador de caracteres visível quando texto > 500 chars (informativo, sem hard limit).
