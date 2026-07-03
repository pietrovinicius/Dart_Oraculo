## [0.2.0] - 2026-07-03

### Adicionado
- **lib/core/services/secure_storage_service.dart**: wrapper sobre flutter_secure_storage para API key, modelo padrão e toggle de biometria. Injeção de dependência via construtor para testabilidade.
- **lib/features/auth/auth_service.dart**: serviço de autenticação local via local_auth com enum AuthResult (success, failed, notAvailable, notConfigured). Verifica disponibilidade de biometria e preferência do usuário antes de autenticar.
- **lib/features/auth/lock_screen.dart**: tela de bloqueio funcional — auto-autentica no init, exibe estado de loading, mensagem de erro em falha, botão para retry manual.
- **test/unit/database/migrations_test.dart**: 9 testes cobrindo criação de tabelas, FTS5 virtual table, e triggers de insert/update/delete sincronizando chunks_fts.
- **test/unit/services/secure_storage_service_test.dart**: 9 testes cobrindo API key CRUD, modelo padrão, e toggle biométrico com FakeSecureStorage in-memory.
- **test/unit/features/auth/auth_service_test.dart**: 7 testes cobrindo todos os cenários de autenticação (disponibilidade, configuração, sucesso, falha).

### Alterado
- **test/unit/app_smoke_test.dart**: corrigido ordenação de imports (directives_ordering lint).
