# Auditoria de Renderização do Chat — Dart Oráculo v0.22.0

**Data:** 2026-07-08  
**Problema reportado:** Resposta confusa, muitos botões "Copiar", diagramação com espaçamentos errados, difícil de ler.

---

## Anatomia de uma Resposta no Chat

```
┌─────────────────────────────────────────────┐
│ [Bolha do Assistente]                        │
│                                              │
│  Texto markdown renderizado...               │  ← MarkdownBody
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ SQL                        [Copiar] ①  │  │  ← Header do code block
│  │                                        │  │
│  │  SELECT * FROM tabela;                 │  │  ← Código
│  └────────────────────────────────────────┘  │
│                                              │
│  Mais texto...                               │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │ SQL                        [Copiar] ②  │  │  ← Outro code block
│  │  INSERT INTO ...                       │  │
│  └────────────────────────────────────────┘  │
│                                              │
│  ☁️ claude-sonnet-4-6  15:34  [📋] ③ [👍][👎] │  ← Footer
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│ Fontes consultadas                           │  ← CitationStrip
│ [Oracle.pdf (p.1)] [Oracle.pdf (p.1)] ...    │
└─────────────────────────────────────────────┘
```

---

## Problemas Identificados

### 1. Excesso de botões "Copiar" — confusão de escopo

| # | Botão | Localização | O que copia | Visível |
|---|---|---|---|---|
| ① | Copiar no code block | Header de cada bloco de código | Só o snippet de código | Sempre que há code block |
| ② | Copiar no code block | Idem, cada bloco tem o seu | Só aquele snippet | Repete N vezes |
| ③ | Copiar no footer | Rodapé da bolha inteira | Todo o conteúdo raw (markdown bruto com ``` e ##) | Sempre em respostas |

**Problema:** Em resposta com 3+ code blocks, o user vê 4+ botões "Copiar" sem distinção visual. Não sabe qual copia o quê.  
**Agravante:** O botão ③ do footer copia markdown bruto (com fences, asteriscos, headers). User espera texto renderizado.

**Sugestão:**
- Renomear ③ para "Copiar tudo" ou usar ícone diferente (`Icons.content_copy` vs `Icons.copy_outlined`)
- Ou remover ③ completamente (Claude Desktop não tem copy da resposta inteira — só por bloco)

---

### 2. Espaçamento vertical excessivo entre parágrafos

**Causa:** `MarkdownStyleSheet` em `message_bubble.dart:85` **não define `blockSpacing`**.  
O flutter_markdown usa default (~8px entre cada elemento block: parágrafo, lista, heading, blockquote).  

Em respostas longas com muitos parágrafos, isso acumula: 5 parágrafos = 40px de espaço "vazio" espalhado.

**Sugestão:** Adicionar `blockSpacing: 8` (ou até `6`) explicitamente para controlar. Ou `4` para respostas densas.

---

### 3. Code blocks com margin vertical dupla

**Causa:** `_CodeBlockWidget` tem `margin: EdgeInsets.symmetric(vertical: 8)` (linha 322).  
Isso se **soma** ao `blockSpacing` do markdown, criando ~16px antes e depois de cada code block.

**Sugestão:** Reduzir para `vertical: 4` ou `vertical: 2`, já que o `blockSpacing` já dá gap.

---

### 4. Enters/quebras de linha aparentes no markdown

**Causa provável:** O modelo retorna `\n\n` entre seções. O flutter_markdown renderiza cada `\n\n` como novo parágrafo com `blockSpacing` aplicado. Quando o modelo usa:
```
Texto.



Outro texto.
```
3 line breaks viram 2 parágrafos com gap triplo entre eles.

**Sugestão:** Pré-processar o `content` antes de passar ao `MarkdownBody` — colapsar 3+ newlines consecutivas em 2:
```dart
final cleanContent = content.replaceAll(RegExp(r'\n{3,}'), '\n\n');
```

---

### 5. Chips de citação parecem clicáveis mas não são

**Causa:** Widget `Chip` sem `onPressed` — visualmente sugere ação mas não faz nada ao tap.

**Sugestão:** Ou adicionar ação (abrir documento/chunk) ou usar visual mais "inerte" (texto plain em Container, sem Chip widget).

---

### 6. Repetição de citações idênticas

**Observação no screenshot:** "Oracle.pdf (p.1)" aparece 10 vezes na faixa de citação. Isso é correto (10 chunks diferentes todos da mesma p.1), mas visualmente parece bug.

**Sugestão:** Deduplicar por filename+page e mostrar contagem: `Oracle.pdf (p.1) ×10` em vez de 10 chips idênticos.

---

### 7. Footer visual denso

O footer empilha: `[ícone motor] [modelo] [hora] ——spacer—— [copiar] [like] [dislike]`

Em telas estreitas ou bolhas largas, tudo fica na mesma linha mas apertado. Os ícones de like/dislike (16px) são muito pequenos para target de toque confiável.

**Sugestão:** Aumentar `size: 16` → `size: 20` nos FeedbackButtons, ou usar `InkWell` com padding maior.

---

### 8. Inline code (backtick) com background escuro em tema claro

**Causa:** `code: AppTextStyles.techMedium.copyWith(backgroundColor: AppColors.surfaceLight)` (linha 97). `AppColors.surfaceLight = 0xFF2A2A2A` — cor DARK hardcoded.

**Sugestão:** Usar `Theme.of(context).colorScheme.surfaceContainerHighest` no lugar.

---

## Mapa Visual dos Problemas

```
Resposta típica:

  [8px blockSpacing]      ← Problema #2
  Parágrafo 1
  [8px blockSpacing]      ← Acumula
  Parágrafo 2
  [8px + 8px margin]      ← Problema #3 (duplo)
  ┌──── Code Block ① ─────┐
  │ SQL        [Copiar] ← │  ← Problema #1 (confunde com ③)
  │  SELECT ...            │
  └────────────────────────┘
  [8px margin + 8px block] ← Problema #3
  Parágrafo 3
  [8px blockSpacing]       
  
  ☁️ sonnet 15:34 [📋③][👍][👎]  ← Problema #1 (outro copiar)

  [Fontes consultadas]
  [Oracle.pdf(p.1)] [Oracle.pdf(p.1)] ... ×10  ← Problema #6
```

---

## Prioridade de Correção

| # | Problema | Esforço | Impacto |
|---|---|---|---|
| 1 | Botões copiar confusos | 30min | 🔴 Alto |
| 2 | blockSpacing excessivo | 5min | 🔴 Alto |
| 3 | Code block margin dupla | 5min | 🟡 Médio |
| 4 | Newlines triplos colapsados | 10min | 🟡 Médio |
| 6 | Citações duplicadas | 30min | 🟡 Médio |
| 8 | Inline code cor dark | 5min | 🟡 Médio |
| 5 | Chips parecem clicáveis | 15min | 🟢 Baixo |
| 7 | Footer denso | 15min | 🟢 Baixo |

---

## Referência: Como Claude Desktop Resolve

- **1 botão copiar** por code block (no header). **Zero** botão copiar na resposta inteira.
- **blockSpacing** reduzido — parágrafos quase colados.
- **Code blocks** sem margin extra — flush com o texto.
- **Citações** não aparecem como chips — aparecem como links inline no texto.
- **Footer** minimalista: só modelo + hora em cinza claro, sem ícones de ação visíveis (aparecem ao hover).
