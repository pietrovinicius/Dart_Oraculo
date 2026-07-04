# Auditoria de Ingestão dos JSONs TASY — Dart Oráculo v0.13.3

**Data:** 2026-07-04  
**Arquivos analisados:**
- `jsons/procedures_functions_packages.json` — 12.0 MB
- `jsons/triggers_eventos.json` — 9.4 MB
- `jsons/tabelas_e_colunas.json` — 133.9 MB

---

## 1. Higiene de Repositório

| Verificação | Resultado |
|---|---|
| `.gitignore` exclui `jsons/` | ✅ Adicionado nesta auditoria |
| `.gitignore` exclui `pdfs/` | ✅ Adicionado nesta auditoria |
| Arquivos já commitados no histórico | ✅ **Nenhum commit anterior** inclui `jsons/` — `git log --all -- jsons/` retorna vazio |
| Status atual | Untracked (correto) |

**Nenhum achado crítico de histórico.**

---

## 2. Diagnóstico dos Arquivos Menores

### procedures_functions_packages.json (12 MB)

| Métrica | Valor |
|---|---|
| Total de linhas | 62.621 |
| Colunas | OWNER, OBJECT_NAME, OBJECT_TYPE, STATUS, CREATED, LAST_DDL_TIME |
| Coluna de agrupamento | OBJECT_NAME |
| Grupos distintos | 61.658 |
| Linhas por grupo | 1.0 média (max 2) |
| Chunks resultantes estimados | ~61.658 |
| Tamanho médio por chunk | ~150 chars (1 linha formatada como tabela markdown) |

**Observação crítica:** Com avg 1 linha por grupo, o chunking por identidade produz **61K chunks de ~150 chars cada**. Cada chunk terá apenas uma linha de metadados do objeto (tipo, status, data de criação). A utilidade RAG é limitada — a pergunta "o que faz a procedure X" não pode ser respondida porque o corpo/código-fonte não está neste arquivo.

### triggers_eventos.json (9.4 MB)

| Métrica | Valor |
|---|---|
| Total de linhas | 5.882 |
| Colunas | OWNER, TRIGGER_NAME, TABLE_OWNER, TABLE_NAME, TRIGGERING_EVENT, TRIGGER_TYPE, STATUS, TRIGGER_BODY |
| Coluna de agrupamento | TRIGGER_NAME |
| Grupos distintos | 5.882 |
| Linhas por grupo | 1.0 (exatamente 1 trigger por linha) |
| Chunks resultantes | 5.882 |
| Tamanho médio por chunk | ~500-2000 chars (inclui TRIGGER_BODY com código) |

**Observação:** Bom para RAG — cada chunk terá o nome do trigger, a tabela associada, o evento, E o corpo do trigger. Perguntas como "qual trigger dispara ao inserir na tabela X" são respondíveis.

---

## 3. Diagnóstico do Arquivo Maior (sem carga)

### tabelas_e_colunas.json (133.9 MB)

| Métrica | Valor |
|---|---|
| Total de linhas | 483.256 |
| Colunas | OWNER, TABLE_NAME, COLUMN_ID, COLUMN_NAME, DATA_TYPE, DATA_LENGTH, DATA_PRECISION, DATA_SCALE, NULLABLE, COLUMN_COMMENT |
| Coluna de agrupamento | TABLE_NAME |
| Grupos distintos (tabelas) | 29.287 |
| Colunas por tabela (média) | 16.5 |
| Colunas por tabela (máxima) | 481 (CPOE_MATERIAL) |
| Colunas por tabela (mediana) | 10 |
| Chunks resultantes | 29.287 |
| Tamanho médio por chunk | ~1.320 chars |
| Maior chunk estimado | ~110.000 chars (CPOE_MATERIAL, 481 colunas) |

**Riscos identificados:**
1. `jsonDecode` de 134MB na thread principal → UI congela por 5-15 segundos
2. 29.287 INSERTs individuais no SQLite → pode levar 30-60s sem feedback
3. O maior chunk (110K chars) excede o que é útil como contexto RAG — será truncado ou consumirá tokens demais

---

## 4. Auditoria de Código do Caminho de Ingestão

| Aspecto | Estado Atual | Risco |
|---|---|---|
| **Parsing (jsonDecode)** | Thread principal (main isolate) | 🔴 Alto para 134MB — UI congela |
| **Inserções SQLite** | Uma a uma via `_db.insert()` em loop, sem transaction explícita | 🟡 Médio — sqflite usa auto-commit por default, lento para 29K inserts |
| **Progresso para dados estruturados** | `onProgress(0.5)` após parsing, `onProgress(1.0)` após chunking | 🟡 Médio — apenas 2 ticks de progresso, não granular |
| **Isolate/compute** | Não utilizado | 🔴 Alto para arquivo grande |
| **Streaming de JSON** | Não utilizado (jsonDecode carrega tudo em memória) | 🔴 Alto — 134MB → ~400MB+ em memória como Map |

---

## 5. Vereditos por Arquivo

### triggers_eventos.json (9.4 MB, 5.882 rows)

**Veredito: ✅ Pode carregar com segurança.**

- 5.8K rows → jsonDecode leva <1s na thread principal
- 5.8K chunks → inserts levam ~5s (aceitável com progresso)
- Tamanho total em memória: ~30MB (confortável)
- Corpus útil para RAG (tem TRIGGER_BODY)

### procedures_functions_packages.json (12 MB, 62.621 rows)

**Veredito: ⚠️ Carrega, mas com risco de travamento perceptível.**

- 62K rows → jsonDecode leva 2-4s (UI congela brevemente)
- 61.6K chunks individuais → inserts levam 30-60s sem feedback granular
- Corpus de utilidade limitada (metadados sem código-fonte)
- **Recomendação:** carregar se necessário, mas avisar o usuário que vai demorar. Considerar se o valor RAG justifica 61K chunks de 1 linha.

### tabelas_e_colunas.json (133.9 MB, 483.256 rows)

**Veredito: ❌ Não deve ser tentado sem mudança de engenharia.**

Mudanças necessárias antes de carregar:

| # | Mudança | Razão |
|---|---|---|
| 1 | **Mover jsonDecode para Isolate** (`compute()`) | 134MB na main thread congela UI por 10-15s |
| 2 | **JSON streaming** (`JsonDecoder` incremental ou chunked read) | Evitar 400MB+ em memória de uma vez |
| 3 | **Inserções em transação por lote** (`db.transaction` com batch de 1000) | 29K inserts individuais = 30-60s; em transaction = 3-5s |
| 4 | **Progresso granular** (por grupo processado, não apenas 2 ticks) | Usuário precisa saber que está progredindo durante 29K chunks |
| 5 | **Limite de tamanho por chunk** (truncar ou subdividir chunks > 5K chars) | CPOE_MATERIAL com 110K chars é inútil como contexto RAG |

---

## 6. Qualidade Esperada de Resposta RAG

### Avaliação estrutural (sem medição de acurácia)

| Aspecto | Avaliação |
|---|---|
| **FTS5 com nomes técnicos** | ✅ Funciona bem para buscas exatas: "PACIENTE", "CD_MEDICO", "TRIGGER_BODY". FTS5 faz match lexical direto. |
| **Perguntas em linguagem natural** | ⚠️ Parcial. "Quais colunas tem a tabela PACIENTE" funciona porque o chunk contém "Tabela PACIENTE, colunas:" (cabeçalho natural injetado pelo chunker). Mas "tabelas de cadastro" não funciona — FTS5 não entende semântica. |
| **Valor do cabeçalho natural** | ✅ Alto. O `structured_data_chunker` injeta "Tabela X, colunas:" — isso dá ao FTS5 texto para casar além dos nomes técnicos. |
| **COLUMN_COMMENT** | ✅ Se populado no TASY, é o melhor campo para busca natural — contém descrição em português da coluna. FTS5 vai casar esses termos. |
| **Limitação fundamental** | FTS5 é lexical, não semântico. Perguntas como "tabelas relacionadas a internação" dependem de os COLUMN_COMMENT ou TABLE_NAME conterem a palavra "internação" ou sinônimos. Não há inferência de relação. |

### Recomendação para maximizar qualidade RAG:
1. Priorizar `tabelas_e_colunas.json` — COLUMN_COMMENT dá contexto natural
2. `triggers_eventos.json` — TRIGGER_BODY é código útil para perguntas sobre lógica
3. `procedures_functions_packages.json` — valor baixo sem código-fonte; considerar se vale os 61K chunks

---

## Resumo de Ações

| Prioridade | Ação | Bloqueio |
|---|---|---|
| 1 | Carregar `triggers_eventos.json` com TRIGGER_NAME | Nenhum — pode rodar agora |
| 2 | Carregar `procedures_functions_packages.json` com OBJECT_NAME | Baixo — UI congela brevemente |
| 3 | Implementar mudanças de engenharia (5 itens) | Antes de carregar `tabelas_e_colunas.json` |
| 4 | Testar qualidade de resposta com corpus real | Após carga dos 2 menores |
