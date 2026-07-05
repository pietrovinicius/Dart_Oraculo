# Plano de Implementação — Promoção de Respostas Aprovadas para RAG

**Data:** 2026-07-05  
**Versão alvo:** v0.18.0  
**Escopo:** Like promove resposta como chunk pesquisável; dislike/remove reverte

---

## Visão Geral

Quando user dá like → resposta vira chunk FTS5 na coleção ativa.  
Quando remove like ou dá dislike → chunk removido imediatamente.

---

## Migration v6

**Novas colunas em `chunks`:**
- `source_type TEXT NOT NULL DEFAULT 'document'` — valores: 'document' | 'promoted_answer'
- `original_message_id INTEGER` — nullable, FK para messages.id

---

## Task 1 — Migration v6 + Teste

**Arquivos:**
- `lib/core/config/app_config.dart` → version 6
- `lib/core/database/migrations.dart` → upgradeV5toV6, allV6
- `lib/core/database/database_helper.dart` → onCreate allV6, onUpgrade <6
- `test/unit/database/migration_v6_test.dart`

**SQL:**
```sql
ALTER TABLE chunks ADD COLUMN source_type TEXT NOT NULL DEFAULT 'document';
ALTER TABLE chunks ADD COLUMN original_message_id INTEGER;
```

---

## Task 2 — Documento sintético "Respostas Aprovadas"

**Arquivo:** `lib/features/chat/chat_controller.dart`

Método `_getOrCreatePromotedDocument(int collectionId)` → retorna doc ID:
- Busca documento com filename = 'Respostas Aprovadas do Oráculo' na coleção
- Se não existe, cria
- Retorna ID

---

## Task 3 — Promoção ao dar like + Teste

**Arquivo:** `lib/features/chat/chat_controller.dart` → `setFeedback()`

Quando `value == 'like'`:
1. Busca mensagem (assistant) pelo ID
2. Busca mensagem anterior (user) na mesma conversa
3. Busca collection_id da conversa
4. `_getOrCreatePromotedDocument(collectionId)`
5. Monta conteúdo:
   ```
   [Resposta aprovada em DD/MM/YYYY | Coleção: {nome}]
   Pergunta: {texto do user}
   Resposta: {texto do assistant}
   ```
6. Insere chunk com source_type='promoted_answer', original_message_id=messageId
7. FTS5 trigger cuida da indexação automática

**Teste RED:**
```dart
test('like promove resposta como chunk pesquisável', () async {
  // Cria conversa + mensagens user/assistant
  // Dá like
  // Verifica chunk com source_type='promoted_answer' existe
  // Verifica FTS5 encontra conteúdo da resposta
});
```

---

## Task 4 — Reversão ao remover like / dislike + Teste

**Arquivo:** `lib/features/chat/chat_controller.dart` → `setFeedback()`

Quando like é removido (toggle off) ou trocado para dislike:
1. Busca chunk com `original_message_id = messageId`
2. Se existe → deleta da tabela chunks (trigger FTS5 cuida do índice)

**Teste RED:**
```dart
test('remover like deleta chunk promovido', () async { ... });
test('dislike direto não promove', () async { ... });
```

---

## Task 5 — Citação diferenciada no citation_strip + Teste

**Arquivo:** `lib/features/chat/widgets/citation_strip.dart`

Quando chunk tem `source_type == 'promoted_answer'`:
- Exibir: `"Resposta aprovada (DD/MM/YYYY)"` em vez de `"filename (p.X)"`
- Detectar pelo chunk_id: query JOIN para pegar source_type

**Mudança no modelo CitationData:**
- Adicionar campo `sourceType` (String?)
- Em `_parseCitations` no chat_screen, fazer JOIN com chunks para obter source_type

**Widget test:**
```dart
testWidgets('exibe citação diferenciada para promoted_answer', ...);
```

---

## Task 6 — Atualizar testes existentes + Verificação + Commit

- Atualizar testes que usam Migrations.allV5 → allV6
- `flutter analyze` limpo
- `flutter test` passando
- Changelog fragment
- Commit

---

## Formato do Chunk Promovido

```
[Resposta aprovada em 05/07/2026 | Coleção: TASY]
Pergunta: o que voce sabe da ADEP_V?
Resposta: A ADEP_V é uma view do sistema TASY que contém dados de adequação...
```

## Formato da Citação

- Documento normal: `"tabelas_e_colunas.json (p.1)"`
- Resposta promovida: `"Resposta aprovada (05/07/2026)"`

---

## Verificação

Após cada task:
- `flutter analyze` limpo
- `flutter test` passando
- Commit individual
