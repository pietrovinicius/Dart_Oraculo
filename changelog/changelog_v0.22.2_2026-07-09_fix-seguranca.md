## [0.22.2] - 2026-07-09

### Segurança
- **lock_screen.dart**: Autenticação biométrica reativada — removida flag `_authDisabled = true`. Casos `notConfigured`/`notAvailable` agora exibem mensagem de erro (não navegam para home).
- **anthropic_service.dart**: Removido log que expunha substring da API key. Agora loga apenas presença e comprimento.
- **anthropic_service.dart**: Removido getter público `apiKey` — FidelityChecker recebe headers prontos.
- **anthropic_service.dart**: Instrução de defesa contra prompt injection adicionada antes do contexto RAG.
- **fidelity_checker.dart**: Refatorado para receber `headers` (Map) em vez de `apiKey` (String) — reduz superfície de exposição de credencial.
- **DebugProfile.entitlements**: Removida entitlement `network.server` desnecessária.

### Adicionado
- **docs/auditoria_seguranca_2026-07-09.md**: Relatório completo de auditoria de segurança cibernética (14 achados).
- **docs/PLANO_CORRECAO_SEGURANCA_2026-07-09.md**: Plano de correção com 5 tasks.
