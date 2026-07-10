# Plano: RAG para Usuário Confuso — 6 Soluções

**Versão alvo:** 0.29.0  
**Data:** 2026-07-10  
**Prioridade:** Alta — UX crítica para usuário leigo.

---

## Diagnóstico

### Problema Central

Usuário escreve "pesquisa entao diarreia e dor abdominal" → FTS5 busca literalmente por esses termos → retorna chunks irrelevantes ou nada → experiência confusa.

### 7 Fraquezas do RAG Atual

| # | Problema | Exemplo | Impacto |
|---|----------|---------|--------|
| **F1** | Sem reformulação de query | "pesquisa entao diarreia" | Palavras filler poluem busca |
| **F2** | Sem correção ortográfica | "dirreia", "abdminal", "prescao" | FTS5 é exact match → 0 resultados |
| **F3** | Sem stemming português | "doenças" ≠ "doença" | Miss em variações morfológicas |
| **F4** | Sem detecção intencionalidade múltipla | "diarreia E dor abdominal" (2 sintomas) | FTS5 OR/AND cru |
| **F5** | Sem re-ranking por relevância | Chunk irrelevante rankeia igual a CID | Noise no topo |
| **F6** | Sem feedback loop | Query ruim → usuário reformula → 0 aprendizado | Erro repetido |
| **F7** | Histórico não influencia busca | Conversa sobre CID → próxima query isolada | Contexto perdido |

---

## Solução 1 — Query Rewrite via LLM (🔴 CRÍTICA)

### Objetivo

Antes de buscar no FTS5, reformular a query do usuário em linguagem técnica/clara.

### Implementação

**Arquivo novo:** `lib/core/services/query_reformatter_service.dart`

**Lógica:**
1. Interceptar query antes do FTS5.
2. Chamar Haiku (rápido + barato) com prompt estruturado:
   ```
   System: Você é um reformulador de queries para busca textual.
   Dada a pergunta confusa do usuário, retorne 1 query limpa e técnica.
   Remova filler, corrija ortografia, priorize termos-chave.
   Responda APENAS a query reformulada, sem explicação.
   
   User: "pesquisa entao diarreia e dor abdominal"
   ```
3. Resposta esperada: `"diarreia dor abdominal"`
4. Enviar query reformulada ao FTS5.
5. Log: `"query original → reformulada"`

**Configuração:**
- Timeout: 2s (fallback para query original)
- Cache: 1h (mesma query reformulada)
- Toggle em Settings: "Reformulação inteligente" (default: ON)
- Custo: ~500 tokens/query (Haiku ~$0.0008)

### Fluxo

```
User input → LLM reformat (2s) → FTS5 search
  └─ timeout/error → FTS5 com original (fallback)
```

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Reformula filler | Unit | "pesquisa entao X" → "X" |
| Corrige typo | Unit | "dirreia" → "diarreia" |
| Timeout fallback | Unit | Após 2s usa original |
| Cache hit | Unit | Segunda chamada não chama LLM |

---

## Solução 2 — Fuzzy/Prefix Matching Expandido (🔴 CRÍTICA, custo zero)

### Objetivo

Tolerância a typos via FTS5 prefix match em cada termo.

### Implementação

**Arquivo modificado:** `lib/core/services/fts_service.dart`

**Lógica:**
1. Na cascata de fallback (após OR), adicionar etapa de prefix:
   ```dart
   // Fallback final: prefix match para cada termo (tolera typos parciais)
   if (rows.isEmpty) {
     final terms = sanitized.replaceAll('"', '').split(' ')
         .where((t) => t.length >= 3)
         .toList();
     if (terms.isNotEmpty) {
       final prefixQuery = terms.map((t) => '${t.substring(0, (t.length * 0.7).ceil())}*').join(' OR ');
       rows = await _executeSearch(prefixQuery, ...);
     }
   }
   ```
2. Log: `"Fallback fuzzy-prefix: $prefixQuery"`

### Exemplo

```
"dirreia" (typo) → prefix "dirre*" → encontra nada
→ trunca 70%: "dirr*" → encontra "diarreia"? Não.
→ Melhor abordagem: prefixo dos termos originais.

Melhor: usar apenas primeiros 3-4 chars de cada termo.
"dirreia" → "dir*" → encontra "diarreia"
"abdminal" → "abd*" → encontra "abdominal"
```

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Prefix match typo | Integration | "dir*" encontra "diarreia" |
| Min 3 chars | Unit | Termos < 3 chars ignorados |

---

## Solução 3 — Context-Aware Search (🟡)

### Objetivo

Usar tema da conversa para refinar busca.

### Implementação

**Arquivo modificado:** `lib/features/chat/chat_controller.dart`

**Lógica:**
1. Extrair tópico dos últimos 2-3 messages assistant (últimas 200 chars).
2. Concatenar tópico extraído à query antes do FTS5:
   ```dart
   String _enrichWithContext(String query, List<Message> recent) {
     if (recent.isEmpty) return query;
     final lastAssistant = recent.lastWhere((m) => m.role == 'assistant', orElse: () => recent.last);
     // Extrair keywords do último response (top 3 substantivos)
     final keywords = _extractTopKeywords(lastAssistant.content, 3);
     if (keywords.isEmpty) return query;
     return '$query ${keywords.join(' ')}';
   }
   ```
3. Log: `"Context-enriched: original='X' → enriched='X + keywords'"`

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Keywords extraídas | Unit | Assistant com "CID A09" → keyword "A09" |
| Conversa vazia → sem enriquecimento | Unit | Query inalterada |

---

## Solução 4 — Re-ranking Heurístico (🟡)

### Objetivo

Filtrar chunks de schema/metadados que passaram no FTS5.

### Implementação

**Arquivo modificado:** `lib/core/services/fts_service.dart`

**Lógica:**
```dart
List<FtsResult> _rerank(List<FtsResult> results) {
  return results.where((r) {
    // Descartar chunks com rank muito ruim
    if (r.rank < -15) return false;
    // Penalizar chunks que são claramente metadados técnicos
    final metadataScore = _countMetadataPatterns(r.content);
    if (metadataScore > 5 && r.rank < -3) return false;
    return true;
  }).toList();
}

int _countMetadataPatterns(String content) {
  final patterns = ['VARCHAR', 'INTEGER', 'NUMBER', 'DATE', '||', 'NOT NULL', 'Tabela '];
  return patterns.where((p) => content.toUpperCase().contains(p.toUpperCase())).length;
}
```

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Schema chunk filtrado | Unit | Chunk com 5+ patterns removido |
| Chunk real preservado | Unit | Chunk CID com rank -2 mantido |

---

## Solução 5 — Sugestões Visuais (🟢)

### Objetivo

Mostrar "Poucos resultados encontrados. Tente refinar..." quando busca é fraca.

### Implementação

**Arquivo modificado:** `lib/features/chat/chat_screen.dart`

**Lógica:**
- Se `_lastFtsQuality == 'weak'` (definido pelo chat_controller quando chunks < 3 ou rank ruim):
  - Exibir message system no chat: "⚠️ Poucos documentos encontrados. Tente ser mais específico."
  - Se query rewrite disponível, mostrar: "Busquei por: [query reformulada]"

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Aviso visível com FTS fraco | Widget | Mensagem aparece quando quality=weak |

---

## Solução 6 — Auto-Retry com Variações (🟢)

### Objetivo

Se busca retorna 0, tentar automaticamente com variações.

### Implementação

**Arquivo modificado:** `lib/features/chat/chat_controller.dart`

**Lógica:**
```dart
// Se FTS5 retorna 0 chunks, tenta variações
if (ftsResults.isEmpty && query.split(' ').length > 2) {
  // Tenta com apenas os 2 primeiros termos não-stopword
  final shortQuery = _sanitizeQuery(query).split(' ').take(2).join(' ');
  ftsResults = await _ftsService.search(shortQuery, collectionId: collectionId, limit: maxChunks);
  if (ftsResults.isNotEmpty) {
    LoggerService.instance.info(_tag, 'Auto-retry com query curta retornou ${ftsResults.length} chunks');
  }
}
```

### Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Retry com query curta | Integration | 0 chunks → retry → encontra |
| Não retenta se já tem resultados | Unit | > 0 chunks → sem retry |

---

## Ordem de Execução

| Fase | Versão | Soluções | Foco |
|------|--------|----------|------|
| A | 0.29.0 | 1 + 2 | Alicerce — reformulação + fuzzy |
| B | 0.30.0 | 3 + 4 | Refinamento — context + re-ranking |
| C | 0.31.0 | 5 + 6 | UX — feedback visual + auto-retry |

---

## Arquivos Novos

```
lib/core/services/query_reformatter_service.dart
test/unit/services/query_reformatter_service_test.dart
```

## Arquivos Modificados

```
lib/core/services/fts_service.dart                 # Sol. 2, 4
lib/features/chat/chat_controller.dart             # Sol. 1, 3, 6
lib/features/chat/chat_screen.dart                 # Sol. 5
lib/features/settings/settings_screen.dart         # Toggle Sol. 1
```
