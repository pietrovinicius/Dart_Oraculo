# Auditoria de UX/UI do Chat — Dart Oráculo v0.20.0

**Data:** 2026-07-05  
**Referência:** Claude Desktop (claude.ai), ChatGPT Desktop  
**Método:** Análise estrutural de código (chat_screen, chat_input, message_bubble, sidebar, citation_strip)

---

## 1. Fluxo: Criar Coleção

### Estado atual
- Botão "+" no header da sidebar abre dialog com TextField para nome
- Coleção criada imediatamente ao confirmar

### Problemas
| # | Severidade | Descrição |
|---|---|---|
| 1.1 | 🟡 Média | Sem validação de nome vazio — user pode criar coleção sem nome |
| 1.2 | 🟢 Baixa | Sem confirmação visual de sucesso após criar (feedback silencioso) |
| 1.3 | 🟢 Baixa | Sem opção de definir instrução da coleção no ato de criação — precisa ir em settings depois |

---

## 2. Fluxo: Criar Conversa

### Estado atual
- Botão "+" ao lado de "Conversas" cria conversa com título "Nova conversa"
- Auto-renomeia baseado na primeira pergunta (via sidebar)

### Problemas
| # | Severidade | Descrição |
|---|---|---|
| 2.1 | 🟡 Média | Conversa aberta pela primeira vez mostra empty state com chips, mas ao clicar num chip e a resposta chegar, a conversa antiga (se trocou) não abre no final — abre no topo |
| 2.2 | 🟢 Baixa | Título "Nova conversa" pouco informativo na sidebar até renomear |

---

## 3. Fluxo: Chat — Caixa de Texto

### Estado atual
- Enter envia, Shift+Enter nova linha
- Botão 📎 (imagem), 🎤 (ditado), Send/Stop
- Preview de imagem com ✕
- Focus visual (borda laranja)
- Cmd+V cola imagem ou texto

### Problemas
| # | Severidade | Descrição |
|---|---|---|
| 3.1 | 🔴 Alta | **Botões 📎 e 🎤 sem rótulo visível** — user novo não sabe o que são. Tooltip só aparece ao hover, mas em macOS trackpad é fácil ignorar |
| 3.2 | 🟡 Média | **Campo não expande visualmente** ao focar — a borda muda de cor mas não há padding/elevation diferenciado. User pode não perceber que está focado |
| 3.3 | 🟡 Média | **maxLines: 5** pode ser insuficiente para queries longas (SQL multi-linha). Sem scroll interno visível quando ultrapassa 5 linhas |
| 3.4 | 🟢 Baixa | Hint text "Pergunte ao Oráculo... (Shift+Enter nova linha)" longo — "(Shift+Enter nova linha)" pode ser tooltip em vez de ocupar espaço |
| 3.5 | 🟢 Baixa | Botão send sem estado disabled visual claro — `onPressed: null` remove cor mas não mostra visualmente "desabilitado" |

---

## 4. Fluxo: Chat — Respostas da IA

### Estado atual
- Bolha escura com markdown renderizado
- Code blocks com header + botão Copiar + texto selecionável
- Footer: ícone motor + nome modelo + timestamp + copiar + like/dislike
- Citação em faixa separada abaixo

### Problemas
| # | Severidade | Descrição |
|---|---|---|
| 4.1 | 🔴 Alta | **Respostas longas sem sumário/collapse** — resposta de 50+ linhas ocupa tela inteira, dificulta scroll para próximas perguntas |
| 4.2 | 🟡 Média | **Citação não é clicável** — chip de fonte consultada não abre/navega ao documento original. Informação estática. |
| 4.3 | 🟡 Média | **Like durante verificação não mostra loading** — user clica, espera 5s sem saber que verificação está rodando (debounce existe mas sem feedback visual de "verificando...") |
| 4.4 | 🟡 Média | **Code block sem detecção de linguagem** — header do code block vazio, não mostra "SQL", "Python", etc. Claude Desktop mostra. |
| 4.5 | 🟢 Baixa | **Bolha max-width 0.7** pode ser muito estreita em telas largas (>1440px). Respostas com tabelas markdown ficam apertadas. |
| 4.6 | 🟢 Baixa | **Timestamp sem data** — em conversas que duram dias, "15:34" é ambíguo. Separador de data existe mas o timestamp per-message não inclui dia. |

---

## 5. Fluxo: Chat — Interações Avançadas

### Estado atual
- Retry bubble após erro de API
- Scroll-to-bottom button (FAB)
- Separador de data (Hoje/Ontem/DD-MM-YYYY)
- Editar mensagem do user (ícone lápis)
- Drag & drop imagem
- Ditado por voz
- Exportar conversa .md

### Problemas
| # | Severidade | Descrição |
|---|---|---|
| 5.1 | 🟡 Média | **Editar mensagem não mostra warning** de que mensagens posteriores serão deletadas. Ação irreversível sem confirmação. |
| 5.2 | 🟡 Média | **Drag overlay cobre 100% da tela** — dificulta ver onde vai soltar. Poderia ser só uma faixa inferior. |
| 5.3 | 🟢 Baixa | **Scroll-to-bottom FAB sempre visível no mesmo lugar** — conflita com última mensagem quando perto do bottom. Deveria ter margem ou sumir quando próximo. |
| 5.4 | 🟢 Baixa | **Ditado sem indicador de nível de áudio** — user não sabe se mic está captando. Só ícone laranja. |

---

## 6. Sidebar — Conversas e Coleções

### Estado atual
- Dropdown de coleção no topo
- Lista de conversas com pin, menu ⋮ (renomear, fixar, exportar, excluir)
- Contagem de documentos no footer
- Versão do app

### Problemas
| # | Severidade | Descrição |
|---|---|---|
| 6.1 | 🟡 Média | **Sem busca/filtro de conversas** — com 20+ conversas, difícil encontrar uma específica |
| 6.2 | 🟡 Média | **Excluir conversa sem confirmação** — ação destrutiva no menu ⋮ sem dialog "Tem certeza?" |
| 6.3 | 🟢 Baixa | **Sem indicador de "conversa com anexo"** — não dá pra saber pela sidebar quais conversas têm docs de trabalho |
| 6.4 | 🟢 Baixa | **Conversas não agrupadas por data** — lista flat sem seção "Hoje", "Ontem", "Semana passada" |

---

## 7. Bugs Identificados

| # | Severidade | Descrição | Arquivo |
|---|---|---|---|
| B1 | 🔴 **Crítico** | ScrollController attached to multiple views — crash intermitente ao trocar conversa rápido | chat_screen.dart:991 (guard existe mas AnimatedSwitcher ainda cria race) |
| B2 | 🟡 Média | Conversa antiga abre no topo em vez do final (scroll position não preservada ao navegar de volta) | chat_screen.dart |
| B3 | 🟡 Média | Like duplo rápido pode disparar 2 verificações apesar do debounce (race entre setState e async) | chat_screen.dart (parcialmente fixado) |

---

## 8. Melhores Práticas Ausentes

| # | Prática | Estado |
|---|---|---|
| MP1 | **Acessibilidade (a11y)** — Semantics labels nos botões de ação | ❌ Ausente. Apenas Tooltip, sem Semantics. |
| MP2 | **Keyboard navigation** — Tab entre botões do footer | ❌ Não implementado |
| MP3 | **Undo/Redo** — Cmd+Z após enviar mensagem | ❌ Não implementado |
| MP4 | **Rate limiting visual** — Feedback quando API está throttled | ❌ Só SnackBar genérico de erro |
| MP5 | **Responsividade** — Layout em telas < 1024px (sidebar colapsa?) | ⚠️ Sidebar toggle existe mas sem breakpoint auto |
| MP6 | **Estado vazio robusto** — Ilustração diferenciada para "sem docs" vs "sem conversa" vs "sem resultado" | ⚠️ Parcial (empty states existem mas são genéricos) |

---

## Resumo Executivo

| Severidade | Quantidade |
|---|---|
| 🔴 Alta / Bug crítico | 3 |
| 🟡 Média | 12 |
| 🟢 Baixa | 10 |
| Melhores práticas | 6 |

**Top 5 para maior impacto com menor esforço:**

1. **4.3** — Loading visual durante verificação de fidelidade (1h)
2. **6.2** — Confirmação antes de excluir conversa (30min)
3. **3.1** — Labels nos botões 📎/🎤 ou indicador mais claro (30min)
4. **5.1** — Warning ao editar que deleta posteriores (30min)
5. **B2** — Conversa abre no final (scroll to bottom ao carregar) (1h)
