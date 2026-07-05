# Plano de Implementação — Exportar Conversa como Markdown

**Data:** 2026-07-05  
**Versão alvo:** v0.19.0  
**Escopo:** Exportar conversa inteira como .md via file picker

---

## Task 1 — Método exportConversationAsMarkdown + Teste

**Arquivo:** `lib/features/chat/chat_controller.dart`

**Método:**
```dart
Future<String> exportConversationAsMarkdown(int conversationId) async { ... }
```

Retorna o conteúdo markdown. Formato:
```markdown
# Conversa: {título}

*Exportado em DD/MM/YYYY às HH:mm | Coleção: {nome}*

---

## 👤 Usuário (HH:mm)

{texto}

---

## 🤖 Assistente (HH:mm) — {modelo}

{texto}

**Fontes:** {citações}

---
```

- Se mensagem tem imagePath → `📎 *[imagem anexada]*` antes do texto
- Se chunk citado tem source_type='promoted_answer' → `Resposta aprovada (data)`
- Se chunk citado é documento → `filename (p.X)`

**Teste RED:**
```dart
test('gera markdown com formato correto', () async { ... });
test('inclui nota de imagem anexada', () async { ... });
test('diferencia citação de documento e resposta promovida', () async { ... });
```

---

## Task 2 — Salvar + file picker + opção na sidebar

**Arquivos:**
- `lib/features/chat/chat_screen.dart` — método `_exportConversation(int id)`
- `lib/features/chat/widgets/sidebar.dart` — opção "Exportar .md" no PopupMenu

**Fluxo:**
1. Gera markdown via controller
2. Salva em AppSupport/exports/{titulo}_{data}.md (cache)
3. Abre file picker save dialog
4. Copia para destino escolhido
5. SnackBar sucesso/erro

**Widget test:**
```dart
testWidgets('menu de contexto contém opção Exportar .md', ...);
```

---

## Task 3 — Verificação + changelog + commit

- `flutter analyze` limpo
- `flutter test` passando
- Changelog fragment
- Commit

---

## Nome do arquivo

`{titulo_conversa}_{YYYY-MM-DD}.md` — caracteres especiais removidos/substituídos.
