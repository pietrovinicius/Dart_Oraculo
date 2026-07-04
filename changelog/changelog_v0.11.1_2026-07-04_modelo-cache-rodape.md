## [0.11.1] - 2026-07-04

### Corrigido
- **lib/features/documents/document_service.dart**: `_generateDescription()` agora usa o modelo selecionado pelo usuário nas configurações (`defaultModel`), não mais Sonnet fixo. Se Opus 4.8 está configurado, descrição é gerada com Opus.
- **lib/features/documents/document_service.dart**: `exportAsMarkdown()` agora verifica se arquivo já existe antes de reprocessar chunks. Cache por identidade — retorna caminho existente sem regenerar. Comentário documenta premissa de que documentos não são editados pós-ingestão.

### Adicionado
- **lib/features/chat/widgets/sidebar.dart**: rodapé fixo com "v0.11.1" (lido de AppConfig.appVersion) e "Dev @PLima" em tipografia técnica monoespaçada, cor cinza discreta.
- **lib/core/config/app_config.dart**: campo `appVersion` para exibição na UI.
