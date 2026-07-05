# Plano de Implementação — Contexto de Trabalho por Conversa (.md)

**Data:** 2026-07-05  
**Versão alvo:** v0.20.0  
**Escopo:** Anexar .md como contexto temporário de conversa (não indexa no RAG)

---

## Visão Geral

.md solto/selecionado → diálogo: "Biblioteca" (ingestão permanente) ou "Nesta conversa" (temporário).  
Contexto injetado no prompt, nunca indexado em FTS5.

---

## Migration v8

**Nova tabela:**
```sql
CREATE TABLE IF NOT EXISTS conversation_context_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id INTEGER NOT NULL REFERENCES conversations(id),
  filename TEXT NOT NULL,
  content TEXT NOT NULL,
  added_at TEXT NOT NULL
);
```

---

## Task 1 — Migration v8 + Teste

**Arquivos:**
- `app_config.dart` → version 8
- `migrations.dart` → createConversationContextAttachments, upgradeV7toV8, allV8
- `database_helper.dart` → onCreate allV8, onUpgrade <8
- `test/unit/database/migration_v8_test.dart`

---

## Task 2 — ChatController: CRUD de anexos + injeção no prompt + Teste

**Arquivo:** `lib/features/chat/chat_controller.dart`

**Novos métodos:**
```dart
Future<void> addContextAttachment(int conversationId, String filename, String content)
Future<List<Map<String, dynamic>>> getContextAttachments(int conversationId)
Future<void> removeContextAttachment(int attachmentId)
```

**Injeção no prompt (em `askQuestion`):**
- Após montar contexto FTS5, buscar attachments da conversa
- Injetar antes do contexto FTS5 com label:
  ```
  --- DOCUMENTO DE TRABALHO: {filename} ---
  {conteúdo, truncado se > maxContextCharsPerChunk}
  --- FIM DOCUMENTO DE TRABALHO ---
  ```
- Ajustar system prompt para mencionar que pode haver "documentos de trabalho" além do contexto RAG

**Testes:**
```dart
test('injeção do conteúdo anexado em perguntas subsequentes')
test('truncagem quando conteúdo excede limite do motor')
test('ausência de injeção depois que anexo removido')
```

---

## Task 3 — Diálogo de escolha de destino + Teste

**Arquivo:** `lib/features/chat/chat_screen.dart`

Quando .md é solto (DropTarget) ou selecionado (file_picker):
1. Detectar extensão .md
2. Mostrar dialog:
   - "📚 Adicionar à biblioteca" → fluxo ingestMarkdown existente
   - "📎 Usar nesta conversa" → lê conteúdo, chama `addContextAttachment`
3. Imagens continuam sem dialog (fluxo direto)

**Widget test:**
```dart
testWidgets('diálogo aparece ao selecionar .md')
```

---

## Task 4 — Indicador no cabeçalho + remoção

**Arquivo:** `lib/features/chat/chat_screen.dart`

- Na toolbar, quando conversa tem attachments, mostrar chip/badge:
  `📎 2 docs` com tooltip listando nomes
- Ao clicar → dropdown com nomes + botão ✕ para remover cada um

---

## Task 5 — Ajuste no prompt de sistema

**Arquivo:** `lib/core/services/anthropic_service.dart`

Adicionar instrução:
```
6. Se usar informação de um DOCUMENTO DE TRABALHO, cite o nome do documento na resposta.
```

---

## Task 6 — Verificação + changelog + commit

- `flutter analyze` limpo
- `flutter test` passando
- Changelog fragment
- Commit

---

## Diálogo de Destino

> **Destino do arquivo**
>
> *{filename}*
>
> [📚 Adicionar à biblioteca] — Indexa permanentemente na coleção. Disponível em todas as conversas.
>
> [📎 Usar nesta conversa] — Contexto de trabalho temporário. Só nesta conversa.
