# Plano: Redução de Custo da API Claude

**Versão alvo:** 0.30.0  
**Data:** 2026-07-10  
**Prioridade:** Alta — custo atual ~$0.22/consulta é proibitivo.

---

## Diagnóstico

### Custo Atual Medido

```
input_tokens=73.211 → $0.22 (Sonnet 5: $3/1M input)
output_tokens=310 → $0.005
Total: ~$0.225 por consulta
```

### Configuração do Usuário (Já Otimizada)

| Setting | Valor | Impacto |
|---------|-------|--------|
| Mensagens de contexto | 10 | OK |
| Chunks por busca | 5 | ✅ Já reduzido |
| Tamanho do chunk | 300 | ⚠️ Só afeta docs novos |

### Causa Raiz

**CSVs indexados com chunking antigo (StructuredDataChunker) geram chunks de 20KB+.**

- CSV CID: 14.274 linhas × 170 colunas → chunks enormes
- `attributes.csv`: schema técnico com centenas de campos
- 5 chunks × 20KB = 100KB = 73K tokens
- **Custo esperado com chunks normais (300 tokens × 5):** ~$0.015
- **Custo real com chunks CSV gigantes:** ~$0.225 (15x mais caro)

---

## Soluções — Ordenadas por Impacto/Esforço

### Sol. 1 — Truncagem Hard Limit no Contexto (Impacto Imediato)

**Arquivo:** `lib/features/chat/chat_controller.dart`

**Lógica:**
- Ao montar contexto, truncar CADA chunk a no máximo `chunkMaxTokens` × 4 chars (≈ 1200 chars para config 300).
- Já existe truncagem no código, mas usa `maxContextCharsPerChunk` do motor (20.000 para Anthropic) → permissivo demais.
- Nova lógica: `min(maxContextCharsPerChunk, userChunkMaxTokens * 4)`.

```dart
// Antes
final maxChars = activeGenerationService.maxContextCharsPerChunk; // 20000!

// Depois
final chunkTokensSetting = await _secureStorage.readRaw('chunk_max_tokens');
final userMaxChars = (int.tryParse(chunkTokensSetting ?? '') ?? AppConfig.chunkMaxTokens) * 4;
final maxChars = userMaxChars.clamp(400, activeGenerationService.maxContextCharsPerChunk);
```

**Resultado:** 5 chunks × 1200 chars = 6KB → ~2K tokens de RAG (vs 73K atual).

**Redução:** ~97% nos tokens de contexto RAG.

### Testes

| Teste | Descrição |
|-------|----------|
| Chunk CSV truncado a userMaxChars | Context ≤ 6KB com config 300 |
| Motor maxChars respeitado se menor | Qwen 4000 chars override |

---

### Sol. 2 — Budget de Tokens Total no Contexto

**Arquivo:** `lib/features/chat/chat_controller.dart`

**Lógica:**
- Definir budget máximo total para contexto: `chunks_budget = chunks_por_busca × chunk_max_tokens × 4`
- Se soma dos chunks excede budget → parar de incluir (não incluir os últimos).
- Log: `"Budget de contexto: ${totalChars}/${budget} chars (${chunks incluídos}/${total} chunks)"`

```dart
final contextBudget = maxChunks * userMaxChars; // ex: 5 * 1200 = 6000 chars
var totalCharsUsed = 0;
for (final result in ftsResults) {
  final content = result.content;
  final truncated = content.length > userMaxChars
      ? content.substring(0, userMaxChars)
      : content;
  if (totalCharsUsed + truncated.length > contextBudget) break;
  totalCharsUsed += truncated.length;
  contextBuffer.writeln(...);
}
```

**Resultado:** Contexto garantidamente ≤ budget.

---

### Sol. 3 — Reingestão Automática de CSVs Antigos

**Arquivo:** `lib/features/documents/document_service.dart`

**Lógica:**
- Comando "Reindexar" na Library Screen para cada documento.
- Ao reindexar: deleta chunks antigos → reingressa com `chunkMaxTokens` atual (300).
- CSVs: usar `CidChunker` (se CID) ou truncar linhas a colunas relevantes.

**Resultado:** Chunks antigos de 20KB → chunks novos de 300 tokens.

---

### Sol. 4 — Roteamento Inteligente de Modelo

**Arquivo:** `lib/features/chat/chat_controller.dart`

**Lógica:**
- Queries simples (≤ 1500 tokens input estimado) → usar **Haiku** ($0.25/1M input = 12x mais barato)
- Queries complexas (múltiplos chunks, histórico longo) → manter **Sonnet**
- Toggle em Settings: "Roteamento automático de modelo" (default: ON)

**Estimativa de custo:**
- Haiku: ~1500 tokens × $0.25/1M = **$0.0004** (vs $0.005 Sonnet)
- 80% das queries são simples → economia de 80%

```dart
String _selectOptimalModel(int estimatedInputTokens, String userSelectedModel) {
  if (userSelectedModel != AppConfig.modelSonnet) return userSelectedModel;
  // Auto-downgrade para Haiku se contexto pequeno
  final autoRouting = await _secureStorage.readRaw('auto_model_routing');
  if (autoRouting == 'false') return userSelectedModel;
  if (estimatedInputTokens < 2000) return 'claude-haiku-4-5-20251001';
  return userSelectedModel;
}
```

---

### Sol. 5 — Prompt Caching (Anthropic Beta)

**Arquivo:** `lib/core/services/anthropic_service.dart`

**Lógica:**
- Anthropic oferece prompt caching: system prompt cacheado = 90% desconto em tokens repetidos.
- Adicionar header `anthropic-beta: prompt-caching-2024-07-31`.
- Marcar system prompt com `cache_control: {type: "ephemeral"}`.

```dart
'system': [
  {
    'type': 'text',
    'text': systemPromptText,
    'cache_control': {'type': 'ephemeral'},
  }
],
```

**Resultado:** System prompt + contexto RAG cacheados → 2ª consulta na mesma sessão custa 90% menos em tokens de input.

---

### Sol. 6 — Desabilitar Query Reformatter para Queries Simples

**Arquivo:** `lib/core/services/query_reformatter_service.dart`

**Já implementado:** queries ≤ 3 palavras não chamam Haiku. Custo: ~$0.0005/query.

Possível melhoria: só chamar reformatter se FTS5 retornou 0 resultados (lazy reformulation).

---

## Comparação de Custos

| Cenário | Tokens Input | Custo/consulta | Redução |
|---------|-------------|----------------|--------|
| **Atual** (chunks CSV 20KB) | 73.000 | $0.225 | — |
| **Sol.1** (truncagem hard limit) | ~5.000 | $0.015 | **-93%** |
| **Sol.1+2** (budget total) | ~5.000 | $0.015 | -93% |
| **Sol.1+4** (Haiku para simples) | ~1.500 | $0.0004 | **-99.8%** |
| **Sol.1+5** (prompt caching) | ~5.000 (cached) | $0.002 | **-99%** |
| **Qwen local** | 0 | $0.00 | -100% |

---

## Ordem de Execução

| Fase | Solução | Impacto | Esforço |
|------|---------|---------|--------|
| **1** | Sol.1 — Truncagem hard limit | -93% imediato | Baixo (5 linhas) |
| **2** | Sol.2 — Budget total | Garante teto | Baixo |
| **3** | Sol.5 — Prompt caching | -90% em sessão | Médio |
| **4** | Sol.4 — Roteamento modelo | -99% para simples | Médio |
| **5** | Sol.3 — Reingestão | Permanente | Alto |

---

## Ação Imediata (Sem Código Novo)

**Reingerir o CSV CID** — deletar e reimportar com `chunk_max_tokens=300`. Os chunks novos terão 300 tokens → 5 chunks × 1200 chars = ~1.5K tokens input → **$0.005/consulta**.

---

## Sobre Qwen Local

| Aspecto | Claude (Sonnet) | Qwen (Local) |
|---------|----------------|---------------|
| Custo | $0.015-0.22/query | $0.00 |
| Qualidade RAG | Excelente | Boa (simples) |
| Velocidade | 2-8s (rede) | 5-30s (CPU local) |
| Offline | ❌ | ✅ |
| Ideal para | Queries complexas, multi-doc | Queries simples, lookup |

**Recomendação:** Usar Qwen para lookups simples ("o que é CID A09?") e Sonnet apenas para análise complexa multi-documento.

---

## Versionamento

| Fase | Versão |
|------|--------|
| Sol. 1 + 2 | 0.30.0 |
| Sol. 5 | 0.31.0 |
| Sol. 4 | 0.32.0 |
| Sol. 3 | 0.33.0 |

---

## Arquivos Modificados

```
lib/features/chat/chat_controller.dart         # Sol. 1, 2, 4
lib/core/services/anthropic_service.dart        # Sol. 5
lib/core/services/query_reformatter_service.dart # Sol. 6
lib/features/documents/document_service.dart   # Sol. 3
lib/features/documents/library_screen.dart     # Sol. 3 (botão Reindexar)
```
