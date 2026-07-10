# Plano: Busca Inteligente para CSV CID — 4 Soluções

**Versão alvo:** 0.28.0  
**Data:** 2026-07-10  
**Prioridade:** Alta — CID é caso de uso central do app.

---

## Diagnóstico

### Situação Atual

- CSV CID tem 14.274 linhas, 170+ colunas por linha.
- Chunking atual (`StructuredDataChunker`) agrupa por coluna → gera chunks enormes com metadados irrelevantes.
- FTS5 indexa o conteúdo completo da linha, incluindo 170 colunas vazias ou técnicas.
- Resultado: busca por "diarreia" compete com noise de campos vazios e colunas de schema.
- Apenas 2 colunas são relevantes para busca CID: `CD_DOENCA_CID` e `DS_DOENCA_CID`.

### Evidência (Log)

```
query="pesquisa entao diarreia e dor abdominal" → sanitized="pesquisa entao diarreia dor abdominal"
FTS5 retornou 8 chunks → todos de "attributes.csv", nenhum de CID
```

O FTS5 encontra "dor" e "abdominal" em chunks de schema (descrições de campos), não no CID.

---

## Solução 1 — Ingestão Inteligente de CSV CID

### Objetivo

Criar pipeline especializado para CSV tipo CID: extrair apenas colunas relevantes e gerar chunks enxutos, indexáveis com alta precisão FTS5.

### Implementação

**Arquivo novo:** `lib/core/services/cid_chunker.dart`

**Lógica:**
1. Detectar CSV CID por presença de colunas `CD_DOENCA_CID` e `DS_DOENCA_CID`.
2. Extrair apenas: código CID, descrição da doença, categoria.
3. Agrupar por categoria CID (ex: A00-A09 = doenças infecciosas intestinais).
4. Gerar chunk com formato:
   ```
   Classificação CID — Doenças infecciosas intestinais (A00-A09)
   - A00: Cólera
   - A01: Febres tifóide e paratifóide
   - A09: Diarreia e gastroenterite de origem infecciosa presumível
   ```

**Benefício:** Chunk enxuto, 100% text-searchable, FTS5 encontra "diarreia" direto.

### Arquivo modificado: `lib/features/documents/document_service.dart`

- Em `ingestStructuredData()`: detectar se CSV é tipo CID.
- Se CID detectado → usar `CidChunker` em vez de `StructuredDataChunker`.

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| CID chunker gera chunks por categoria | Unit | Valida agrupamento A00-A09 |
| Chunk contém descrição da doença | Unit | "DIARREIA" presente no content |
| FTS5 encontra "diarreia" após reingestão | Integration | search() retorna chunk CID |

---

## Solução 2 — Chunking Enriquecido com Sinônimos Clínicos

### Objetivo

Expandir descrições CID com termos clínicos relacionados para que busca por sintomas encontre diagnósticos.

### Implementação

**Arquivo novo:** `lib/core/services/cid_synonym_expander.dart`

**Lógica:**
1. Mapa estático de sinônimos/manifestações para categorias CID comuns:
   ```dart
   static const _synonyms = {
     'A09': ['diarreia', 'gastroenterite', 'desidratação', 'vômito', 'náusea', 'fezes líquidas'],
     'R10': ['dor abdominal', 'cólica', 'dor de barriga', 'abdome agudo'],
     'K58': ['síndrome intestino irritável', 'cólon irritável', 'diarreia crônica'],
     // ... top 100 CIDs mais buscados
   };
   ```
2. Ao gerar chunk CID, anexar sinônimos no final:
   ```
   A09: Diarreia e gastroenterite de origem infecciosa presumível
   Termos relacionados: diarreia, gastroenterite, desidratação, vômito, fezes líquidas
   ```
3. FTS5 indexa os sinônimos → busca por "fezes líquidas" encontra A09.

### Escopo Mínimo (MVP)

- Mapear top 50 categorias CID com 5-10 sinônimos cada.
- Expandir progressivamente via feedback (log queries que retornam 0 resultados).

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Sinônimos anexados ao chunk | Unit | Chunk A09 contém "fezes líquidas" |
| Busca por sinônimo encontra CID | Integration | search("vômito") retorna chunk A09 |

---

## Solução 3 — Fallback Web Search para Queries sem Resultado Local

### Objetivo

Quando FTS5 retorna 0 chunks relevantes (ou todos com rank muito ruim), usar busca web como fallback para enriquecer contexto.

### Implementação

**Arquivo modificado:** `lib/features/chat/chat_controller.dart`

**Lógica:**
1. Após FTS5 retornar resultados, avaliar qualidade:
   - Se 0 chunks retornados, OU
   - Se melhor rank > -0.5 (threshold de relevância baixa)
2. Se qualidade insuficiente E web search habilitado:
   - Fazer query web com termos originais do usuário
   - Incluir resultados web no contexto com label `[Fonte: web]`
3. Log: `"FTS5 insuficiente (rank=${bestRank}) → fallback web search"`

**Novo:** `lib/core/services/web_search_service.dart`

- Busca via DuckDuckGo Instant Answer API (gratuita, sem API key)
- Ou fallback: instruir modelo a usar conhecimento geral se `general_knowledge_enabled`
- Rate limit: max 1 busca web por pergunta

### Fluxo

```
User query → FTS5 search → resultados?
  ├─ SIM (rank bom) → monta contexto RAG normal
  └─ NÃO (0 ou rank ruim) → web search fallback
       └─ combina local + web no contexto
```

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Fallback ativado com 0 chunks | Unit | web search chamado quando FTS5 vazio |
| Fallback desativado com chunks bons | Unit | web search NÃO chamado |
| Resultado web incluído no contexto | Unit | context contém `[Fonte: web]` |

---

## Solução 4 — Query Expansion via LLM (Pré-busca)

### Objetivo

Antes de enviar query ao FTS5, expandir termos com sinônimos clínicos via chamada rápida ao LLM.

### Implementação

**Arquivo novo:** `lib/core/services/query_expander_service.dart`

**Lógica:**
1. Antes da busca FTS5, enviar ao modelo (Haiku/flash — barato e rápido):
   ```
   System: Você é um assistente de expansão de query médica.
   Dada a pergunta do usuário, retorne 3-5 termos técnicos/CID
   que seriam relevantes para busca textual.
   Responda APENAS os termos, separados por vírgula.
   
   User: "diarreia e dor abdominal"
   ```
2. Resposta esperada: `"A09, K58, R10, gastroenterite, cólica"`
3. Adicionar termos expandidos à query FTS5 (OR):
   ```
   sanitized = "diarreia dor abdominal A09 K58 R10 gastroenterite cólica"
   ```
4. Limitar a 8 termos total (já implementado).

### Configuração

- Toggle em Settings: "Expansão inteligente de query" (default: ON)
- Modelo usado: mais barato disponível (Haiku/flash) — ~500 tokens/chamada
- Timeout: 3s — se exceder, usa query original sem expansão
- Cache: guardar expansões por 24h para mesma query (evita custo repetido)

### Fluxo

```
User query → [expansão LLM (3s max)] → FTS5 search (termos expandidos)
  └─ fallback: se LLM timeout → FTS5 com query original
```

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Expansão adiciona termos CID | Unit | "diarreia" → inclui "A09" |
| Timeout não bloqueia busca | Unit | Após 3s usa query original |
| Cache evita chamada repetida | Unit | Segunda chamada retorna do cache |

---

## Ordem de Execução (Recomendada)

| Fase | Solução | Justificativa |
|------|---------|---------------|
| 1 | **Sol. 1** — Ingestão inteligente CID | Resolve causa raiz (chunks inúteis) |
| 2 | **Sol. 2** — Sinônimos clínicos | Expande cobertura sem custo de API |
| 3 | **Sol. 4** — Query expansion LLM | Inteligência adaptativa para queries novas |
| 4 | **Sol. 3** — Web search fallback | Safety net final quando local insuficiente |

### Dependências

```
Sol.1 (independente) ──┐
Sol.2 (depende de 1) ──┼── Sol.4 (independente) ── Sol.3 (independente)
```

---

## Impacto Esperado

| Query de exemplo | Antes | Depois (com 4 soluções) |
|-----------------|-------|-------------------------|
| "diarreia e dor abdominal" | 0 chunks CID, retorna schema noise | Chunks A09, R10, K58 |
| "cólera" | Pode não achar (sem sinônimo) | Chunk A00 + sinônimos |
| "fezes líquidas criança" | 0 resultados | Expansão → A09, P783 |
| "CID para COVID" | Depende de indexação | Expansão → U07 |

---

## Riscos e Mitigações

| Risco | Mitigação |
|-------|----------|
| Mapa de sinônimos incompleto | Expandir progressivamente; Sol.4 (LLM) cobre lacunas |
| Query expansion LLM lenta | Timeout 3s + cache 24h |
| Web search retorna lixo | Filtrar resultados por relevância antes de incluir |
| Reingestão CID invalida chunks antigos | Implementar re-ingestão que deleta chunks antigos do doc |
| Custo API expansão LLM | Haiku barato (~$0.001/query); cache reduz 80% chamadas |

---

## Versionamento

| Fase | Versão |
|------|--------|
| Sol. 1 + 2 | 0.28.0 |
| Sol. 4 | 0.29.0 |
| Sol. 3 | 0.30.0 |

---

## Arquivos Novos

```
lib/core/services/cid_chunker.dart            # Sol.1
lib/core/services/cid_synonym_expander.dart    # Sol.2
lib/core/services/web_search_service.dart      # Sol.3
lib/core/services/query_expander_service.dart  # Sol.4
test/unit/services/cid_chunker_test.dart
test/unit/services/cid_synonym_expander_test.dart
test/unit/services/web_search_service_test.dart
test/unit/services/query_expander_service_test.dart
```

## Arquivos Modificados

```
lib/features/documents/document_service.dart   # Sol.1 — detectar CSV CID
lib/features/chat/chat_controller.dart         # Sol.3 + 4 — fallback + expansão
lib/core/services/fts_service.dart             # Sol.4 — receber termos expandidos
```
