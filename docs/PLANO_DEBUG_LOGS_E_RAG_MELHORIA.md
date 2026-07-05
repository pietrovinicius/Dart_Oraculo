# Plano de Implementação — Logs Detalhados + Melhoria do RAG

**Data:** 2026-07-05  
**Versão alvo:** v0.17.0  
**Escopo:** Enriquecer console para debug + corrigir busca FTS5 + melhorar assertividade

---

## Diagnóstico do Problema Atual

### Bug crítico no FTS5: OR transforma toda busca em lixo

Query do user: `"o que voce sabre da ADEP_V?"`  
Após sanitização: `"o" OR "que" OR "voce" OR "sabre" OR "da" OR "ADEP" OR "V"`  

**Resultado:** Retorna qualquer chunk que contenha a letra "V" ou a palavra "que" — ou seja, TODOS os chunks do banco. Os 10 retornados são os de pior rank (FTS5 `rank` é negativo; ORDER BY rank ASC retorna os mais relevantes, mas quando toda palavra comum matcha, o BM25 fica diluído).

### Problemas identificados:

1. **OR entre TODOS os termos** → stopwords ("o", "que", "da") dominam resultados
2. **Underscore removido** → "ADEP_V" vira "ADEP" + "V" como termos separados
3. **Sem stopwords filtering** → palavras portuguesas comuns poluem busca
4. **Console pobre** → impossível ver query sanitizada, chunks retornados, contexto enviado
5. **Chunking de JSON** → documentos estruturados (tabelas_e_colunas.json) fragmentados por parágrafos que não existem em JSON
6. **Nenhum log dos chunks no contexto** → não dá pra saber o que o modelo recebeu

---

## Parte 1 — Logs Detalhados para Debug

### Task 1.1 — Enriquecer logs no ChatController.askQuestion

**Arquivo:** `lib/features/chat/chat_controller.dart`

Logs a adicionar:
```
[ChatController] askQuestion — query original: "o que voce sabre da ADEP_V?"
[ChatController] askQuestion — query sanitizada FTS5: "ADEP_V"
[ChatController] FTS5 retornou 10 chunks:
  #1 [rank=-4.23] chunk_id=45, doc="tabelas_e_colunas.json", p.1, preview="CREATE TABLE ADEP_V..."
  #2 [rank=-3.88] chunk_id=12, doc="Oracle19c.pdf", p.3, preview="A view ADEP_V contém..."
  ...
[ChatController] Contexto montado: 3.2KB (10 chunks, truncados: 0)
[ChatController] Histórico: 4 mensagens recentes
[ChatController] Enviando ao motor: claude-sonnet-4-6
```

### Task 1.2 — Log da query sanitizada no FtsService

**Arquivo:** `lib/core/services/fts_service.dart`

```dart
LoggerService.instance.info(_tag, 'search() query="$query" → sanitized="$sanitized"');
```

### Task 1.3 — Log detalhado de cada chunk retornado

No ChatController, após FTS5 retornar, logar cada chunk com rank + preview dos primeiros 80 chars.

### Task 1.4 — Log do tamanho do contexto enviado

Após montar contexto, logar tamanho total em chars e quantos chunks foram truncados.

---

## Parte 2 — Fix da Busca FTS5

### Task 2.1 — Remover OR, usar AND implícito + phrase match

**Arquivo:** `lib/core/services/fts_service.dart` → `_sanitizeQuery()`

**Problema:** `words.join(' OR ')` retorna tudo.  
**Solução:**

```dart
String _sanitizeQuery(String query) {
  // Remove caracteres especiais exceto underscore (preserva ADEP_V)
  final cleaned = query.replaceAll(RegExp(r'[^\w\s\p{L}_]', unicode: true), ' ');
  
  // Filtra stopwords portuguesas
  final words = cleaned.split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !_isStopword(w))
      .toList();

  if (words.isEmpty) return '';

  // Estratégia: AND implícito (FTS5 default quando sem operador)
  // Termos com underscore preservados como frase exata
  return words.map((w) => w.contains('_') ? '"$w"' : w).join(' ');
}
```

### Task 2.2 — Stopwords português

**Arquivo:** `lib/core/services/fts_service.dart`

```dart
static const _stopwords = {
  'a', 'o', 'e', 'é', 'de', 'do', 'da', 'dos', 'das',
  'em', 'no', 'na', 'nos', 'nas', 'um', 'uma', 'uns', 'umas',
  'por', 'para', 'com', 'sem', 'que', 'se', 'ou', 'mas',
  'como', 'esse', 'essa', 'este', 'esta', 'isso', 'isto',
  'ele', 'ela', 'eles', 'elas', 'eu', 'tu', 'nos', 'vos',
  'me', 'te', 'lhe', 'ao', 'aos', 'as', 'os',
  'voce', 'você', 'meu', 'sua', 'seu',
  'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be',
  'of', 'and', 'or', 'in', 'on', 'at', 'to', 'for',
};

bool _isStopword(String word) => _stopwords.contains(word.toLowerCase());
```

### Task 2.3 — Preservar underscore na sanitização

**Atual:** `RegExp(r'[^\w\s\p{L}]')` — `\w` inclui underscore, OK.  
**Mas:** A tokenização do FTS5 por default usa underscore como separador de token.

**Solução:** Termos com underscore devem ser buscados como frase exata (`"ADEP_V"`).

### Task 2.4 — Fallback: busca com prefixo quando AND retorna zero

```dart
// Se AND retorna vazio, tenta com * (prefix match)
if (results.isEmpty && words.length == 1) {
  final prefixQuery = '${words.first}*';
  results = await _searchRaw(prefixQuery, ...);
}
```

---

## Parte 3 — Melhorias de Relevância do RAG

### Task 3.1 — Chunking inteligente para JSON

**Arquivo:** `lib/core/services/chunking_service.dart`

**Problema:** JSONs como `tabelas_e_colunas.json` contêm dados estruturados (arrays de objetos). Chunking por parágrafo fragmenta cada entrada arbitrariamente.

**Solução:** Detectar JSON e chunkar por entrada de array top-level:

```dart
List<TextChunk> chunkJson(String content) {
  // Parse JSON
  // Se é array, cada item é um chunk
  // Se é objeto, cada key top-level é um chunk
  // Prefix cada chunk com metadados (nome da tabela, etc.)
}
```

### Task 3.2 — Prompt RAG mais assertivo

**Arquivo:** `lib/core/services/anthropic_service.dart` → `buildRequestBody`

**Atual:**
```
Você é o Dart Oráculo... Responda com base exclusivamente no contexto fornecido...
```

**Melhorado:**
```
Você é o Dart Oráculo, assistente de conhecimento pessoal.

INSTRUÇÕES:
1. Responda SOMENTE com base no CONTEXTO abaixo.
2. Se a informação não está no contexto, diga claramente: "Não encontrei essa informação nos documentos indexados."
3. Cite o documento fonte e página quando possível.
4. Se o contexto contém informação parcial, mencione o que encontrou e o que falta.
5. NÃO invente informação que não está no contexto.

--- CONTEXTO (recuperado via busca) ---
{contexto com formato: [documento.ext, p.X]: conteúdo}
--- FIM DO CONTEXTO ---
```

### Task 3.3 — Contexto com metadados claros por chunk

**Arquivo:** `lib/features/chat/chat_controller.dart`

**Atual:** `[filename, p.?]: conteúdo`  
**Melhorado:**
```
[Fonte: tabelas_e_colunas.json | Relevância: 0.92 | Chunk 3/15]
CONTEÚDO:
{conteúdo do chunk}
```

### Task 3.4 — Aumentar maxChunksPerQuery para queries curtas

Queries curtas (1-2 palavras como "ADEP_V") podem precisar de mais chunks para encontrar match relevante. Queries longas já têm contexto suficiente.

```dart
final effectiveLimit = query.split(' ').length <= 2 
    ? AppConfig.maxChunksPerQuery * 2  // 20 para queries curtas
    : AppConfig.maxChunksPerQuery;     // 10 para queries longas
```

---

## Parte 4 — Testes

### Task 4.1 — Teste da nova sanitização

```dart
test('preserva underscore como phrase match', () {
  expect(service.sanitizeQuery('ADEP_V'), '"ADEP_V"');
});

test('remove stopwords portuguesas', () {
  expect(service.sanitizeQuery('o que é a ADEP_V'), '"ADEP_V"');
});

test('AND implícito para múltiplos termos', () {
  expect(service.sanitizeQuery('tabela medicamentos'), 'tabela medicamentos');
});
```

### Task 4.2 — Teste do chunking JSON

```dart
test('JSON array chunka por item', () {
  final json = '[{"name":"ADEP"},{"name":"XPTO"}]';
  final chunks = service.chunkJson(json);
  expect(chunks.length, 2);
});
```

---

## Ordem de Execução

1. **Task 1.1-1.4** — Logs detalhados (independente, valor imediato para debug)
2. **Task 2.1-2.4** — Fix FTS5 (bug crítico, maior impacto)
3. **Task 3.2** — Prompt melhorado (rápido, alto impacto)
4. **Task 3.3** — Contexto formatado (melhora clareza)
5. **Task 3.1** — Chunking JSON (complexo, impacto em docs estruturados)
6. **Task 3.4** — Limit dinâmico (simples, melhora queries curtas)
7. **Task 4.1-4.2** — Testes (TDD nos itens acima)

---

## Impacto Esperado

| Problema | Antes | Depois |
|---|---|---|
| Query "ADEP_V" | Retorna chunks sobre Oracle genérico | Retorna chunks com ADEP_V literal |
| Stopwords | Poluem busca, diluem rank | Removidas |
| Debug | 3 linhas de log | ~15 linhas com query, chunks, contexto |
| JSON docs | Fragmentados sem sentido | Chunkados por entrada lógica |
| Prompt | Genérico | Instruções claras de citação e limites |

---

## Verificação

Após cada task:
- `flutter analyze` limpo
- `flutter test` passando
- Commit individual

Após todas:
- Teste manual: perguntar "ADEP_V" com os mesmos docs → deve encontrar
- Changelog fragment
- Build macOS
