## [0.31.0] - 2026-07-10

### Adicionado
- **kimi_service.dart**: Novo motor de geração Kimi K2.6 (Moonshot AI) implementando GenerationService. API compatível OpenAI, streaming SSE, endpoint api.moonshot.ai/v1, janela 256K tokens, maxContextCharsPerChunk=80000.
- **app_config.dart**: Constantes `modelKimi`, `kimiBaseUrl`, `kimiModel`.
- **storage_keys.dart**: Chaves `kimiApiKey` e `kimiWarningDismissed` para Keychain.
- **secure_storage_service.dart**: Métodos `getKimiApiKey()`, `setKimiApiKey()`, `deleteKimiApiKey()`, `hasKimiApiKey()`.
- **chat_input.dart**: Kimi K2.6 adicionado ao seletor de modelo (entre Opus e Qwen).
- **chat_screen.dart**: Aviso de API externa na primeira seleção de Kimi — "Não há garantia de que seus dados não serão usados para treinamento ou estudos pela provedora." Com opção "Não mostrar novamente".
- **chat_screen.dart**: Integração completa — selecionar Kimi verifica chave, exibe aviso, instancia KimiService.
- **settings_screen.dart**: Seção "Chaves de API" redesenhada com 2 cards (Anthropic + Kimi). Indicador visual ✅/⚠️ por provedor. Chave Kimi opcional.
- **settings_screen.dart**: Kimi K2.6 adicionado à lista de modelos padrão.
- **test/unit/services/kimi_service_test.dart**: 7 testes (parsing SSE, [DONE], erro 401/429, sem chave, modelDisplayName, maxContextCharsPerChunk).
- **docs/plano_kimi_multiplas_chaves.md**: Plano de implementação completo.

### Comportamento
- Kimi disponível em todas as coleções (sem bloqueio).
- Sem chave configurada → item Kimi aparece no seletor mas reverte com toast ao tentar usar.
- Aviso de API externa exibido uma vez — checkbox "Não mostrar novamente" persiste no Keychain.
- Custo Kimi: ~$0.001/1K input tokens (~10x mais barato que Sonnet).
