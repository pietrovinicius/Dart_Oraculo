## [0.23.1] - 2026-07-09

### Removido
- **settings_screen.dart**: Seção "Busca na Internet" e campo Brave Search API key removidos da UI.
- **chat_controller.dart**: Fluxo de web search fallback comentado (marcado WEB_SEARCH_DISABLED).
- **chat_screen.dart**: Toggle "Busca na web" removido do dialog de configurações da coleção.

### Motivo
- Busca na internet não é conceito do app. O Dart Oráculo é RAG pessoal local — conhecimento vem exclusivamente dos documentos indexados + conhecimento geral do modelo (quando habilitado).
