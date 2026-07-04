## [0.11.1] - 2026-07-04

### Corrigido
- **lib/features/documents/document_service.dart**: `_generateDescription()` agora usa o modelo selecionado pelo usuário nas configurações (`defaultModel` passado ao construtor), não mais Sonnet fixo. Se Opus 4.8 está configurado, descrição é gerada com Opus.
- **lib/features/documents/document_service.dart**: `exportAsMarkdown()` agora verifica se arquivo já existe antes de reprocessar chunks. Cache por identidade — retorna caminho existente sem regenerar. Comentário documenta premissa de que documentos não são editados pós-ingestão.

### Adicionado
- **lib/features/chat/widgets/sidebar.dart**: rodapé fixo com versão do app (lida dinamicamente via `package_info_plus` do pubspec.yaml) e "Dev @PLima" em tipografia técnica monoespaçada, cor cinza discreta. Fallback para `AppConfig.appVersion` se `PackageInfo.fromPlatform()` falhar.
- **lib/core/config/app_config.dart**: campo `appVersion` como fallback estático.
- **pubspec.yaml**: dependência `package_info_plus: ^8.0.0` para leitura dinâmica da versão.
- **test/unit/features/documents/document_service_test.dart**: 3 novos testes — modelo Sonnet na geração de descrição, modelo Opus na geração de descrição, cache hit no exportAsMarkdown (segunda chamada retorna path existente sem regravar).
- **test/widget/chat_screen_test.dart**: 1 novo teste — rodapé da sidebar exibe versão passada e "Dev @PLima".

### Nota técnica
- **Versão no rodapé**: lida dinamicamente via `PackageInfo.fromPlatform()` (package_info_plus), que lê a versão declarada em `pubspec.yaml`. Não é string fixa — atualiza automaticamente a cada bump de versão no pubspec.
