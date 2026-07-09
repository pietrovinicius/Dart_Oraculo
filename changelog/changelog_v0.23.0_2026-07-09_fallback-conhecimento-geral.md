## [0.23.0] - 2026-07-09

### Adicionado
- **migrations.dart**: Migration v10 — colunas `general_knowledge_fallback` em collections e `response_source` em messages.
- **chat_screen.dart**: Dialog "Configurações da coleção" com 3 toggles (conhecimento geral, busca web, verificar fidelidade). Acessível via ícone ⚙️ na sidebar.
- **anthropic_service.dart**: Duas variantes de system prompt — estrito (toggle OFF) e permissivo com fallback de conhecimento geral (toggle ON).
- **ollama_service.dart**: Mesma lógica de variante permissiva para motor Qwen local.
- **generation_service.dart**: Param `allowGeneralKnowledge` na interface `streamResponse()`.
- **chat_controller.dart**: Lê toggle `general_knowledge_fallback` da coleção, passa ao motor, persiste `response_source` ('rag' | 'general' | 'web').
- **citation_strip.dart**: Indicador visual neutro (✨ + texto muted) quando `response_source == 'general'`.
- **chat_controller.dart**: Trava na promoção por like — resposta de conhecimento geral exige confirmação ("Promover") antes de inserir na base.
- **message.dart**: Campo `responseSource` no modelo Message.
- **sidebar.dart**: Callback `onCollectionSettings` + botão ⚙️ no seletor de coleção.
- **chat_controller.dart**: Getter `database` para acesso ao DB na UI de settings de coleção.

### Alterado
- **database_helper.dart**: `databaseVersion` → 10, `onCreate` usa `allV10`, `onUpgrade` inclui v9→v10.
- **app_config.dart**: `databaseVersion` → 10.
- **chat_screen.dart**: Dialog de confirmação de promoção usa `confirmationMessage` dinâmico. Botão renomeado para "Promover".
