# Plano: Fix Query Grande no Chat — Erro Genérico + FTS5 Explode

**Versão alvo:** 0.27.0  
**Data:** 2026-07-10  
**Prioridade:** Alta — afeta UX diretamente.

---

## Diagnóstico

### O que aconteceu

1. Usuário colou uma query SQL grande (~30 linhas) no chat perguntando sobre erro de ambiguidade.
2. O `_sanitizeQuery` do FTS5 tratou CADA palavra do SQL como termo de busca → gerou query FTS5 com ~40 termos.
3. Query gigante OR com 40 termos executou lentamente e/ou o FTS5 retornou resultados irrelevantes.
4. A API Anthropic provavelmente retornou erro (timeout ou token limit com contexto RAG ruim).
5. O catch genérico `catch (_)` engoliu o erro e mostrou apenas "Falha ao gerar resposta" sem detalhes.

### Problemas identificados

| # | Problema | Impacto |
|---|----------|--------|
| P1 | `_sanitizeQuery` não limita número de termos — explode com textos longos | FTS5 query monstruosa, resultados irrelevantes |
| P2 | Não existe limite de caracteres no input do chat | Permite submissão de textos enormes sem aviso |
| P3 | Mensagem "Falha ao gerar resposta" é genérica — não mostra causa | Usuário não sabe o que corrigir |
| P4 | Bloco de código na query deveria ser ignorado pelo FTS5 — apenas a pergunta natural importa | Keywords SQL poluem a busca |

---

## Etapas de Correção

### Etapa 1 — Limitar termos na sanitização FTS5

**Arquivo:** `lib/core/services/fts_service.dart`

**Lógica:**
- Após filtrar stopwords e selecionar termos prioritários, limitar a no máximo **8 termos** na query FTS5.
- Se query original tem mais de 8 termos, pegar apenas os primeiros 8 (ou os 8 mais relevantes: técnicos primeiro).

```dart
// Antes
return priority
    .map((w) => w.contains('_') ? '"$w"' : w)
    .join(' ');

// Depois
final limited = priority.take(8).toList();
return limited
    .map((w) => w.contains('_') ? '"$w"' : w)
    .join(' ');
```

**Justificativa:** FTS5 com mais de 8 termos OR gera resultados ruidosos. 8 termos é suficiente para capturar a intenção.

---

### Etapa 2 — Extrair intenção da query (ignorar code blocks)

**Arquivo:** `lib/core/services/fts_service.dart`

**Lógica:**
- Antes de sanitizar, detectar se a pergunta contém bloco de código (linhas com keywords SQL como SELECT/FROM/WHERE ou indentação consistente).
- Se detectar code block: extrair APENAS o texto fora do bloco como query FTS5.
- Heurística simples: se mais de 50% das linhas começam com keyword SQL ou indentação de 4+ espaços, considerar tudo como code e usar apenas a primeira/última linha de texto natural.

```dart
String _extractNaturalLanguage(String query) {
  final lines = query.split('\n');
  final sqlKeywords = RegExp(r'^\s*(SELECT|FROM|WHERE|AND|OR|INSERT|UPDATE|DELETE|JOIN|LEFT|RIGHT|GROUP|ORDER|HAVING|UNION|CREATE|ALTER|DROP)\b', caseSensitive: false);
  final natural = lines.where((l) => !sqlKeywords.hasMatch(l) && l.trim().isNotEmpty).toList();
  if (natural.isEmpty) return query; // fallback: usa tudo
  return natural.join(' ');
}
```

---

### Etapa 3 — Mensagem de erro detalhada

**Arquivo:** `lib/features/chat/chat_screen.dart`

**Lógica:**
- No bloco `catch`, capturar a exceção e incluir a mensagem real no estado.
- Exibir ao usuário: "Falha ao gerar resposta: [causa]" em vez do genérico.

```dart
// Antes
} on AnthropicException catch (_) {
  if (mounted) setState(() => _lastFailedQuestion = text);
} catch (_) {
  if (mounted) setState(() => _lastFailedQuestion = text);
}

// Depois
} on AnthropicException catch (e) {
  if (mounted) setState(() {
    _lastFailedQuestion = text;
    _lastError = e.message;
  });
} catch (e) {
  if (mounted) setState(() {
    _lastFailedQuestion = text;
    _lastError = e.toString();
  });
}
```

- Na UI onde mostra "Falha ao gerar resposta", exibir `_lastError` como subtitle (texto muted, truncado a 100 chars).

---

### Etapa 4 — Limite visual no input (soft limit)

**Arquivo:** `lib/features/chat/widgets/chat_input.dart`

**Lógica:**
- Não bloquear envio (queries longas são legítimas com código colado).
- Exibir indicador de caracteres quando texto > 500 chars: "1.247 / ∞" (informativo, não limitante).
- Não há hard limit — o modelo aceita textos grandes, o problema é no FTS5.

---

## Ordem de Execução

1. **Etapa 2** (extrair linguagem natural) — resolve causa raiz
2. **Etapa 1** (limitar termos) — safety net para qualquer query
3. **Etapa 3** (erro detalhado) — UX feedback
4. **Etapa 4** (indicador de chars) — UX informativa

---

## Testes

| Teste | Tipo | Descrição |
|-------|------|----------|
| Query SQL grande sanitizada | Unit | Confirma que `_sanitizeQuery` limita a 8 termos |
| Extração de linguagem natural | Unit | Confirma que texto "ME AJUDA..." é extraído, SQL ignorado |
| Erro detalhado visível | Widget | Confirma que mensagem de erro mostra causa |

---

## Riscos

| Risco | Mitigação |
|-------|----------|
| Heurística de code block falha em queries mistas | Fallback: se nenhuma linha natural, usa query completa |
| 8 termos pode ser pouco para perguntas complexas | Termos técnicos priorizados já cobrem a intenção |

---

## Versionamento

- Bump: `0.26.0` → `0.27.0`
- Fragment: `changelog/changelog_v0.27.0_2026-07-10_fix-query-grande.md`
