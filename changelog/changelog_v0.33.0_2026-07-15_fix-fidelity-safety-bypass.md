## [0.33.0] - 2026-07-15

### Corrigido
- **fidelity_checker.dart**: catch block e error paths agora retornam `isGrounded: false` (conservador) em vez de `true` — safety check NUNCA é bypassado em caso de erro.

### Adicionado
- **fidelity_checker.dart**: campo `reason` em `FidelityCheckResult` explica por que a verificação falhou (HTTP erro, resposta vazia, parsing impossível, exceção de rede).
- **fidelity_checker_test.dart**: testes para comportamento conservador em erro HTTP 500 e exceção de rede.
