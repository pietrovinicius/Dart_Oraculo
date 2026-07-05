# Plano de Implementação — Melhorias RAG v2

**Data:** 2026-07-05  
**Versão alvo:** v0.17.0 (mesma entrega)  
**Escopo:** Refinar busca FTS5 para queries com termos técnicos

---

## Problemas Identificados (console real)

Query: `"tem procedure em cima dessa ADEP ?"`  
Sanitizada: `"tem procedure cima dessa ADEP"`  
Resultado: AND falha → OR retorna chunks genéricos de "ADEP_OBTER_*"  

- "tem", "cima", "dessa" não são stopwords mas deveriam ser
- OR dilui rank — matches parciais em termos irrelevantes sobem
- Termos técnicos (ALLCAPS, underscore) não são priorizados

---

## Task 1 — Expandir stopwords

**Arquivo:** `lib/core/services/fts_service.dart`

Adicionar ao set `_stopwords`:
```dart
// Verbos/palavras comuns que não agregam à busca
'tem', 'ter', 'pode', 'sabe', 'sabre', 'faz', 'fazer',
'sobre', 'cima', 'dessa', 'nessa', 'desse', 'nesse',
'existe', 'existir', 'qual', 'quais', 'onde', 'quando',
'algum', 'alguma', 'alguns', 'algumas',
'mais', 'muito', 'tambem', 'também', 'ainda', 'já', 'ja',
'aqui', 'ali', 'lá', 'la',
```

---

## Task 2 — Priorizar termos técnicos na busca

**Arquivo:** `lib/core/services/fts_service.dart` → `_sanitizeQuery()`

**Lógica:**
1. Após remover stopwords, classificar termos:
   - **Técnicos:** contém underscore OU são ALLCAPS (≥3 chars)
   - **Comuns:** tudo o resto
2. Se há termos técnicos → usar SÓ eles na query (mais precisos)
3. Se não há técnicos → usar todos os termos comuns (AND implícito)

**Exemplo:**
- `"tem procedure cima dessa ADEP"` → técnicos: `[ADEP]`, comuns: `[procedure]`
- Query final: `"ADEP"` (só o técnico, mais preciso)
- Fallback se 0 resultados: `"ADEP" OR procedure`

```dart
String _sanitizeQuery(String query) {
  final cleaned = query.replaceAll(RegExp(r'[^\w\s\p{L}_]', unicode: true), ' ');
  final words = cleaned.split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !_isStopword(w))
      .toList();

  if (words.isEmpty) return '';

  // Separa termos técnicos de comuns
  final technical = words.where(_isTechnicalTerm).toList();
  final common = words.where((w) => !_isTechnicalTerm(w)).toList();

  // Prioriza técnicos se existem
  final priorityTerms = technical.isNotEmpty ? technical : words;

  return priorityTerms
      .map((w) => w.contains('_') ? '"$w"' : w)
      .join(' ');
}

bool _isTechnicalTerm(String word) {
  if (word.contains('_')) return true;
  if (word.length >= 3 && word == word.toUpperCase()) return true;
  return false;
}
```

---

## Task 3 — Fallback inteligente em cascata

**Arquivo:** `lib/core/services/fts_service.dart` → `search()`

**Cascata:**
1. Busca com termos técnicos (AND)
2. Se 0 → busca com todos os termos não-stopword (AND)
3. Se 0 → busca com OR de todos
4. Se 0 → busca com prefix match (`ADEP*`)

```dart
var rows = await _executeSearch(sanitized, collectionId, effectiveLimit);

if (rows.isEmpty && _hasCommonTerms) {
  // Tenta com todos os termos (AND)
  rows = await _executeSearch(allTermsQuery, ...);
}
if (rows.isEmpty) {
  // Tenta OR
  rows = await _executeSearch(orQuery, ...);
}
if (rows.isEmpty && words.length == 1) {
  // Prefix match
  rows = await _executeSearch('${words.first}*', ...);
}
```

---

## Task 4 — Testes + Commit

**Arquivo:** `test/unit/services/fts_service_test.dart`

Testes novos:
```dart
test('termos técnicos ALLCAPS priorizados sobre comuns', () async {
  // Seed chunk com ADEP
  // Query: "tem algo sobre ADEP" → busca só "ADEP"
  // Deve encontrar
});

test('prefix match como último fallback', () async {
  // Query: "ADEP_OBT" → prefix → encontra ADEP_OBTER_*
});
```

---

## Impacto Esperado

| Query | Antes | Depois |
|---|---|---|
| "tem procedure em cima dessa ADEP" | OR genérico → tudo | Só "ADEP" → chunks ADEP* |
| "o que voce sabe da ADEP_V" | AND "sabe ADEP_V" → 0 → OR genérico | Só "ADEP_V" → chunk exato |
| "existe trigger na ACCESS_ITEM" | OR diluído | Só "ACCESS_ITEM" → chunk exato |

---

## Verificação

- `flutter analyze` limpo
- `flutter test` passando
- Teste manual no app com queries reais
- Commit
