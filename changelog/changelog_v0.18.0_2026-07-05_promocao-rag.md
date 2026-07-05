## [0.18.0] - 2026-07-05

### Adicionado
- **chat_controller.dart**: Like promove resposta como chunk FTS5 pesquisável na coleção ativa.
- **chat_controller.dart**: Documento sintético "Respostas Aprovadas do Oráculo" criado automaticamente na primeira promoção.
- **chat_controller.dart**: Reversão imediata ao remover like ou trocar para dislike.
- **citation_strip.dart**: Citação diferenciada — "Resposta aprovada (DD/MM/YYYY)" com fundo laranja sutil.
- **migrations.dart**: Migration v6 — colunas source_type e original_message_id em chunks.
- **promotion_test.dart**: 6 testes cobrindo promoção, reversão, doc sintético, FTS5 pesquisável.
- **migration_v6_test.dart**: 2 testes cobrindo fresh install e upgrade.

### Formato do chunk promovido
```
[Resposta aprovada em DD/MM/YYYY | Coleção: TASY]
Pergunta: o que voce sabe da ADEP_V?
Resposta: ADEP_V é uma view do TASY para adequação...
```
