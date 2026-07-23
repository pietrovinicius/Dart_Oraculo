## [0.34.0] - 2026-07-23

### Corrigido
- **lib/features/chat/chat_screen.dart**: descrição automática de documentos agora respeita o provider selecionado nas configurações, usando Kimi quando `kimi-k2.6` estiver ativo.
- **lib/features/chat/chat_description_generation_service_resolver.dart**: adicionado resolver dedicado para escolher o provider de descrição sem duplicar lógica na tela de chat.
- **test/unit/features/chat/chat_description_generation_service_resolver_test.dart**: adicionada cobertura para seleção de Kimi, Qwen, Anthropic e ausência de chave Kimi.
- **test/unit/features/documents/document_service_test.dart**: adicionada cobertura para geração de descrição via `KimiService`.
