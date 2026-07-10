# Plano: Suporte a Arquivos .txt no RAG

**Versão alvo:** 0.26.0  
**Data:** 2026-07-10  
**Complexidade:** Baixa — reutiliza pipeline existente de markdown.

---

## Contexto

O app suporta PDF, Markdown (.md), CSV e JSON. Arquivos `.txt` (texto plano) não são aceitos, mas o pipeline `ingestMarkdown` já processa texto puro sem necessidade de parsing especial — texto plano é subset válido de markdown.

---

## Mudanças Necessárias

| # | Arquivo | Alteração |
|---|---------|----------|
| 1 | `lib/features/chat/chat_screen.dart:770` | Adicionar `'txt'` à lista `allowedExtensions` do file picker |
| 2 | `lib/features/chat/chat_screen.dart` | No handler de importação, rotear `.txt` para `ingestMarkdown` (mesmo que `.md`) |
| 3 | `lib/features/chat/chat_screen.dart:1057` | Atualizar texto do drop overlay: "Solte a imagem, .md ou .txt aqui" |
| 4 | `lib/features/chat/chat_screen.dart` | Aceitar `.txt` no drag & drop (mesmo tratamento que `.md` — dialog destino biblioteca vs conversa) |

---

## Detalhamento

### Etapa 1 — File Picker aceita .txt

```dart
// Antes
allowedExtensions: ['pdf', 'md', 'csv', 'json'],

// Depois
allowedExtensions: ['pdf', 'md', 'txt', 'csv', 'json'],
```

### Etapa 2 — Roteamento no handler de importação

Localizar o switch/if que decide qual método chamar com base na extensão. Adicionar `.txt` ao mesmo branch de `.md`:

```dart
if (ext == 'md' || ext == 'txt') {
  // Roteia para ingestMarkdown
}
```

### Etapa 3 — Drag & drop aceita .txt

No handler de drag & drop, `.md` já tem tratamento especial (dialog "Biblioteca" vs "Conversa"). Estender para `.txt`:

```dart
if (ext == 'md' || ext == 'txt') {
  _showMdDestinationDialog(...);
}
```

### Etapa 4 — Texto do overlay

Atualizar label visual durante arraste para incluir `.txt`.

---

## Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Importação .txt via file picker | Widget | Confirma que .txt é aceito e ingerido como markdown |
| Drag & drop .txt | Widget | Confirma dialog de destino aparece |
| Chunks gerados | Unit | Confirma que texto plano é chunked corretamente |

---

## Riscos

| Risco | Mitigação |
|-------|----------|
| Arquivo .txt com encoding não-UTF8 | `utf8.decode` com `allowMalformed: true` (mesmo padrão que .md usa) |
| Arquivo .txt muito grande (>50MB) | Mesmo limite de batch já existente (yield entre batches de 1000 chunks) |

---

## Não-escopo

- Não haverá normalização markdown em .txt (diferente de PDF que passa por `MarkdownNormalizer`). Texto plano já é válido como markdown.
- Não haverá dialog de coluna de agrupamento (isso é só para CSV/JSON estruturado).

---

## Versionamento

- Bump: `0.25.0` → `0.26.0`
- Fragment: `changelog/changelog_v0.26.0_2026-07-10_suporte-txt.md`
