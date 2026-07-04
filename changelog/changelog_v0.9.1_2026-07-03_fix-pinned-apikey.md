## [0.9.1] - 2026-07-03

### Corrigido
- **lib/core/database/migrations.dart**: adicionado `ALTER TABLE conversations ADD COLUMN pinned` no upgradeV1toV2. Bancos criados na v1 original (sem coluna pinned) causavam erro "no such column: pinned" ao listar conversas.
- **lib/features/settings/settings_screen.dart**: chave de API exibida mascarada (primeiros 10 + •••••••• + últimos 4 caracteres). Impede salvar versão mascarada com validação "Limpe o campo e cole a nova chave".
- **test/unit/database/migrations_test.dart**: teste de upgrade usa schema v1 original (sem pinned) para simular banco legado corretamente.
