# Plano de Implementação — Melhorias de UX do Chat

**Data:** 2026-07-05  
**Base:** docs/auditoria_ux_chat_v0.20_2026-07-05.md  
**Ordem:** por prioridade e dependência

---

## Sprint A — Alta Prioridade (bugs + impacto imediato)

### A1. Fix B2 — Conversa antiga abre no final
**Arquivo:** `lib/features/chat/chat_screen.dart` → `_loadMessages()`  
**Mudança:** Após carregar mensagens, chamar `_scrollToBottom()` para posicionar no final (última mensagem).  
**Teste:** Abrir conversa com 20+ mensagens → deve scrollar ao final automaticamente.

### A2. Fix B1 — ScrollController multiple views (melhorar guard)
**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Mudança:** Remover AnimatedSwitcher do ListView (causa 2 views simultâneas durante fade). Usar crossfade no conteúdo externo ou aceitar transição sem animação no ListView.  
**Alternativa:** Criar novo ScrollController por conversa em vez de reusar um só.

### A3. Loading visual durante verificação de fidelidade
**Arquivo:** `lib/features/chat/widgets/message_bubble.dart` + `chat_screen.dart`  
**Mudança:** Enquanto `_feedbackInProgress` contém o messageId, mostrar CircularProgressIndicator(size: 12) no lugar do ícone de like.  
**UI:** Ícone like → spinner laranja → ícone like (se aprovado) ou dialog.

### A4. Confirmação antes de excluir conversa
**Arquivo:** `lib/features/chat/chat_screen.dart` → `_deleteConversation()`  
**Mudança:** Mostrar AlertDialog "Excluir conversa '{título}'? Esta ação não pode ser desfeita." com [Cancelar] [Excluir].  

### A5. Warning ao editar mensagem
**Arquivo:** `lib/features/chat/chat_screen.dart` → `_submitEdit()`  
**Mudança:** Antes de deletar mensagens posteriores, mostrar dialog: "Editar esta mensagem vai remover {N} mensagens posteriores. Continuar?"  

---

## Sprint B — Média Prioridade (qualidade percebida)

### B1. Respostas longas — collapse/expand
**Arquivo:** `lib/features/chat/widgets/message_bubble.dart`  
**Mudança:** Se conteúdo > 500 chars, mostrar apenas primeiras 300 chars + botão "Ver mais ▼". Ao expandir, mostra tudo + botão "Ver menos ▲".  
**Exceção:** Nunca colapsa durante streaming.

### B2. Code block com detecção de linguagem
**Arquivo:** `lib/features/chat/widgets/message_bubble.dart` → `_CodeBlockBuilder`  
**Mudança:** Extrair info de linguagem do bloco markdown (````sql`, ````python`). Exibir no header do code block.  
**Fonte:** `element.attributes['class']` do markdown parser.

### B3. Citação clicável
**Arquivo:** `lib/features/chat/widgets/citation_strip.dart`  
**Mudança:** Ao clicar no chip de citação, abrir dialog com preview do chunk completo. Ou navegar para a biblioteca com o documento destacado.

### B4. Busca/filtro de conversas na sidebar
**Arquivo:** `lib/features/chat/widgets/sidebar.dart`  
**Mudança:** TextField de busca acima da lista de conversas. Filtra por título em tempo real.

### B5. Drag overlay menor
**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Mudança:** Overlay cobre só a área inferior (input + 30%) em vez de 100%. Ou usar borda pontilhada sem cobrir conteúdo.

### B6. Labels visuais nos botões 📎 e 🎤
**Arquivo:** `lib/features/chat/widgets/chat_input.dart`  
**Mudança:** Adicionar texto compacto abaixo ou ao lado dos ícones em telas largas. Ou usar chips: `[📎 Imagem]` `[🎤 Ditado]`.

### B7. Like duplo — feedback visual imediato
**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Mudança:** Ao clicar like, mudar ícone para filled imediatamente (optimistic UI). Se verificação falhar, reverter. Já parcialmente implementado (`setState(() => _feedbacks[messageId] = value)`).

---

## Sprint C — Baixa Prioridade (polish)

### C1. maxLines dinâmico no input
**Arquivo:** `lib/features/chat/widgets/chat_input.dart`  
**Mudança:** `maxLines: null` com `constraints: BoxConstraints(maxHeight: 200)` para permitir scroll interno em queries muito longas.

### C2. Hint text mais curto
**Arquivo:** `lib/features/chat/widgets/chat_input.dart`  
**Mudança:** Hint: `"Pergunte ao Oráculo..."`. Mover `"(Shift+Enter nova linha)"` para tooltip do campo ou primeiro uso.

### C3. Bolha max-width responsiva
**Arquivo:** `lib/features/chat/widgets/message_bubble.dart`  
**Mudança:** `maxWidth: min(MediaQuery.width * 0.7, 800)` — cap absoluto em telas largas.

### C4. Scroll-to-bottom FAB margem
**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Mudança:** `bottom: 80` (acima do input) em vez de `bottom: 16` que pode sobrepor última mensagem.

### C5. Indicador áudio no ditado
**Arquivo:** `lib/features/chat/widgets/chat_input.dart`  
**Mudança:** Quando `_isListening`, adicionar AnimatedContainer com pulsação (scale animation) no ícone do mic.

### C6. Conversas agrupadas por data na sidebar
**Arquivo:** `lib/features/chat/widgets/sidebar.dart`  
**Mudança:** Antes de renderizar cada conversa, verificar se mudou de dia. Inserir header "Hoje", "Ontem", "DD/MM".

### C7. Indicador de conversa com anexo na sidebar
**Arquivo:** `lib/features/chat/widgets/sidebar.dart`  
**Mudança:** Badge "📎" no ListTile da conversa quando `conversation_context_attachments` tem registros.

### C8. Timestamp com data em conversas longas
**Arquivo:** `lib/features/chat/widgets/message_bubble.dart`  
**Mudança:** Se separador de data foi renderizado acima, timestamp mostra só hora. Se não (mesma view), mostra "05/07 15:34".

### C9. Botão send estado disabled visual
**Arquivo:** `lib/features/chat/widgets/chat_input.dart`  
**Mudança:** Quando disabled, ícone send com opacity 0.3 explícito + cor textMuted.

### C10. Validação nome coleção
**Arquivo:** `lib/features/chat/widgets/sidebar.dart` (ou dialog de criação)  
**Mudança:** Desabilitar botão "Criar" quando TextField está vazio.

---

## Sprint D — Melhores Práticas

### D1. Accessibility — Semantics labels
**Arquivos:** todos os widgets  
**Mudança:** Adicionar `Semantics(label: ...)` em botões de ação, like/dislike, copiar, editar, mic, send.

### D2. Keyboard navigation
**Arquivo:** `lib/features/chat/widgets/message_bubble.dart`  
**Mudança:** Botões de ação focáveis via Tab. `FocusTraversalGroup` no footer.

### D3. Rate limiting visual
**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Mudança:** Quando API retorna 429, mostrar SnackBar específico: "Limite de requisições atingido. Aguarde X segundos." com countdown.

### D4. Sidebar auto-collapse em telas pequenas
**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Mudança:** `MediaQuery.of(context).size.width < 1024` → sidebar começa colapsada.

### D5. Empty states diferenciados
**Arquivos:** `chat_screen.dart`  
**Mudança:** 3 visuais diferentes: sem coleção selecionada, sem conversa, sem documentos na coleção.

### D6. Feedback de sucesso ao criar coleção
**Arquivo:** sidebar ou dialog de criação  
**Mudança:** SnackBar "Coleção '{nome}' criada" após inserir.

---

## Ordem de Execução Sugerida

| Ordem | Item | Esforço | Impacto |
|---|---|---|---|
| 1 | A1 (scroll ao final) | 30min | Alto |
| 2 | A4 (confirmar excluir) | 30min | Alto |
| 3 | A3 (loading like) | 1h | Alto |
| 4 | A5 (warning editar) | 30min | Alto |
| 5 | A2 (ScrollController fix) | 2h | Alto |
| 6 | B6 (labels botões) | 30min | Médio |
| 7 | B2 (code language) | 1h | Médio |
| 8 | B4 (busca conversas) | 2h | Médio |
| 9 | B1 (collapse respostas) | 2h | Médio |
| 10 | C1-C10 | 30min cada | Baixo |
| 11 | D1-D6 | 1h cada | Best practice |

---

## Verificação

Após cada item:
- `flutter analyze` limpo
- `flutter test` passando
- Commit individual com changelog fragment

Após sprint completo:
- Build macOS para confirmar
- Teste manual dos fluxos afetados
