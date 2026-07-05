## [0.19.0] - 2026-07-05

### Adicionado
- **fidelity_checker.dart**: Verificador de fidelidade cruzado (Sonnet↔Opus) antes de promover resposta.
- **chat_controller.dart**: Checagem roda apenas no like; skip em Qwen e quando toggle desligado.
- **chat_controller.dart**: `forcePromote()` para confirmar promoção após dialog.
- **chat_screen.dart**: AlertDialog "Verificação de fundamentação" quando checagem sinaliza afirmações não fundamentadas.
- **migrations.dart**: Migration v7 — coluna `verify_before_promote` em collections (default 1=ligado).
- **anthropic_service.dart**: Getter `apiKey` público para uso pelo FidelityChecker.
- **fidelity_checker_test.dart**: 4 testes (grounded, not grounded, erro HTTP, cache_control).
- **migration_v7_test.dart**: 2 testes (fresh install, upgrade).

### Comportamento
- Like em resposta Anthropic → verificador cruzado valida fundamentação → promove se OK.
- Like em resposta Anthropic não fundamentada → dialog confirma com user → promove ou cancela.
- Like em resposta Qwen → promove direto (sem segundo motor disponível).
- Toggle por coleção: ligado por default em todas, desligável individualmente.
- cache_control: ephemeral nos chunks do verificador (reduz custo API).
