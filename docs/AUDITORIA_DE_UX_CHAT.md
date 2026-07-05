# Auditoria de UX do Chat — Dart Oráculo v0.14.0

**Data:** 2026-07-04  
**Referência:** Claude Desktop (claude.ai)  
**Método:** Análise estrutural de código + guidelines UI/UX Pro Max + comparação funcional

---

## O que já funciona bem (igual ou próximo ao Claude Desktop)

- ✅ Streaming token a token
- ✅ Cronômetro "Pensando... Xs" com contador real
- ✅ Botão Stop durante geração
- ✅ Markdown rendering nas respostas (headings, listas, blockquotes)
- ✅ Code blocks com botão "Copiar" dedicado + feedback visual "Copiado"
- ✅ Botão Copy geral por resposta inteira
- ✅ Like/Dislike por resposta com toggle
- ✅ Auto-scroll durante streaming
- ✅ Mensagem do user aparece imediatamente (antes da resposta)
- ✅ Sidebar com coleções, conversas, renomear, fixar, deletar
- ✅ Seleção de texto dentro de cada bolha
- ✅ Enter envia, Shift+Enter nova linha
- ✅ Cmd+V cola normalmente
- ✅ Modelo visível no footer da resposta
- ✅ Timestamp discreto (HH:mm)

---

## Gaps Identificados

### Alta Prioridade

| # | Gap | Descrição | No Claude Desktop |
|---|---|---|---|
| 1 | **Citação com filename real** | Faixa mostra "chunk #ID" em vez do nome do documento | Mostra nome do arquivo fonte |
| 2 | **Retry de mensagem** | Após erro de API, não há botão "Tentar novamente" inline | Botão retry aparece na mensagem que falhou |
| 3 | **Scroll-to-bottom button** | Em conversas longas, se scrollou para cima, não há forma rápida de voltar ao final | Seta "↓" flutuante aparece quando não está no bottom |

### Média Prioridade

| # | Gap | Descrição | No Claude Desktop |
|---|---|---|---|
| 4 | **Editar mensagem do user** | Não permite editar e reenviar uma pergunta anterior | Ícone de editar ao hover na mensagem do user |
| 5 | **Input focus visual** | Campo de input sem indicação visual quando focado | Borda sutil ao focar |

### Baixa Prioridade

| # | Gap | Descrição | No Claude Desktop |
|---|---|---|---|
| 6 | **Separador de data** | Conversas longas sem agrupamento por dia | Divider "Hoje", "Ontem", "3 de julho" |
| 7 | **Ícone do motor** | Só texto do modelo, sem ícone visual | Logo pequeno ao lado do nome do modelo |
| 8 | **Transição suave** | Mensagens aparecem sem animação ao trocar conversa | Fade-in sutil |
| 9 | **Empty state de conversa nova** | Conversa recém-criada sem visual diferenciado | Logo + sugestões contextuais |
| 10 | **Feedback tátil like/dislike** | Sem animação ao clicar | Scale + cor transition |

---

## Métricas de Referência

| Componente | Linhas de código | Complexidade |
|---|---|---|
| chat_screen.dart | 904 | Alta (orquestra tudo) |
| message_bubble.dart | 298 | Média |
| chat_input.dart | 99 | Baixa |
| sidebar.dart | 282 | Média |
| citation_strip.dart | 71 | Baixa |

---

## Conclusão

15 funcionalidades já implementadas corretamente. 10 gaps identificados.  
Top 3 para maior salto de qualidade: citação real (#1), retry (#2), scroll-to-bottom (#3).
