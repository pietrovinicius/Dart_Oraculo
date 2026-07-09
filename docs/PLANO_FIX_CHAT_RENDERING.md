# Plano de Correção — Renderização do Chat

**Data:** 2026-07-08  
**Base:** docs/auditoria_chat_rendering_2026-07-08.md  
**Versão alvo:** v0.22.0 (mesma entrega)

---

## Task 1 — Resolver confusão dos botões Copiar

**Arquivo:** `lib/features/chat/widgets/message_bubble.dart`

**Mudança:**
- Remover botão ③ (copiar resposta inteira) do footer da bolha
- Manter apenas copiar por code block (①②) — mesmo padrão do Claude Desktop
- Resultado: user copia código específico, não markdown bruto

**Alternativa se quiser manter:** renomear para ícone diferente (`Icons.select_all`) com tooltip "Copiar tudo"

---

## Task 2 — Reduzir blockSpacing do MarkdownBody

**Arquivo:** `lib/features/chat/widgets/message_bubble.dart` → `MarkdownStyleSheet`

**Mudança:**
```dart
styleSheet: MarkdownStyleSheet(
  blockSpacing: 6, // era default ~8-16
  ...
)
```

Reduz espaçamento entre parágrafos, listas, headings.

---

## Task 3 — Reduzir margin do code block

**Arquivo:** `lib/features/chat/widgets/message_bubble.dart` → `_CodeBlockWidget`

**Mudança:**
```dart
margin: const EdgeInsets.symmetric(vertical: 4), // era 8
```

---

## Task 4 — Colapsar newlines triplos

**Arquivo:** `lib/features/chat/widgets/message_bubble.dart`

**Mudança:** Antes de passar `content` ao `MarkdownBody`:
```dart
final cleanContent = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');
```

---

## Task 5 — Deduplicar citações na faixa

**Arquivo:** `lib/features/chat/chat_screen.dart` → `_parseCitations()`

**Mudança:** Após montar lista de `CitationData`, deduplicar por (filename + page):
```dart
final seen = <String>{};
final deduped = <CitationData>[];
for (final c in citations) {
  final key = '${c.filename}_${c.page}';
  if (!seen.contains(key)) {
    seen.add(key);
    deduped.add(c);
  }
}
return deduped;
```

---

## Task 6 — Inline code cor dinâmica

**Arquivo:** `lib/features/chat/widgets/message_bubble.dart` → `MarkdownStyleSheet`

**Mudança:**
```dart
code: AppTextStyles.techMedium.copyWith(
  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
),
```

---

## Task 7 — Chips citação visual inerte (não parecer clicável)

**Arquivo:** `lib/features/chat/widgets/citation_strip.dart`

**Mudança:** Trocar `Chip` por `Container` com texto + borda sutil — remove affordance de tap.

**Ou:** Manter `Chip` mas adicionar `onPressed` que abre preview do chunk.

---

## Task 8 — Footer: ícones feedback maiores

**Arquivo:** `lib/features/chat/widgets/message_bubble.dart` → `_FeedbackButton`

**Mudança:** `size: 16` → `size: 20` nos ícones like/dislike.

---

## Ordem de Execução

| # | Task | Esforço | Impacto |
|---|---|---|---|
| 1 | Remover botão copiar footer | 2min | 🔴 |
| 2 | blockSpacing: 6 | 1min | 🔴 |
| 3 | Code block margin: 4 | 1min | 🟡 |
| 4 | Colapsar newlines | 2min | 🟡 |
| 5 | Deduplicar citações | 10min | 🟡 |
| 6 | Inline code cor dinâmica | 2min | 🟡 |
| 7 | Chips visual inerte | 10min | 🟢 |
| 8 | Ícones feedback maiores | 1min | 🟢 |

**Total estimado:** ~30 min

---

## Verificação

- `flutter analyze` limpo
- `flutter test` passando
- Changelog fragment
- Commit
- Hot restart + teste visual com resposta longa + code blocks
