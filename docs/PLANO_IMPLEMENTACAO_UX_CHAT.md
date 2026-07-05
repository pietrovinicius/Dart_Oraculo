# Plano de Implementação — Melhorias de UX do Chat

**Data:** 2026-07-04  
**Base:** docs/AUDITORIA_DE_UX_CHAT.md  
**Ordem:** por prioridade e dependência

---

## Sprint A — Alta Prioridade (impacto imediato)

### A1. Citação com filename real
**Arquivo:** `lib/features/chat/chat_screen.dart` → `_parseCitations()`  
**Mudança:** Fazer JOIN de chunk_id com chunks→documents para obter filename real.  
**Atual:** `CitationData(filename: 'chunk #$id')`  
**Novo:** Query: `SELECT d.filename, c.page FROM chunks c JOIN documents d ON d.id = c.document_id WHERE c.id IN (?)`  
**Teste:** Atualizar integration test para verificar que citação mostra filename.

### A2. Retry de mensagem após erro
**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Mudança:** Quando a API retorna erro, mostrar botão "Tentar novamente" na posição onde estaria a resposta do assistant. Ao clicar, reenvia a última pergunta.  
**UI:** Bolha com ícone de erro + texto "Falha ao gerar resposta" + botão "↻ Tentar novamente"  
**Estado:** Novo campo `_lastError` que guarda a mensagem de erro e a pergunta original.

### A3. Scroll-to-bottom button
**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Mudança:** `NotificationListener<ScrollNotification>` detecta quando o user scrollou para cima. Mostra `FloatingActionButton` com seta ↓ que chama `_scrollToBottom()`.  
**Posição:** Canto inferior direito do painel de chat, acima do input.  
**Visibilidade:** Só aparece quando `scrollController.offset < maxScrollExtent - 100`.

---

## Sprint B — Média Prioridade (qualidade percebida)

### B1. Input focus visual
**Arquivo:** `lib/features/chat/widgets/chat_input.dart`  
**Mudança:** Adicionar `focusedBorder` com cor `AppColors.accentOrange` no Container do input quando o TextField está focado. Usar `ValueListenableBuilder` no `_focusNode` para detectar foco.

### B2. Editar mensagem do user
**Arquivo:** `lib/features/chat/widgets/message_bubble.dart` + `chat_screen.dart` + `chat_controller.dart`  
**Mudança:**
1. Ícone de editar (lápis) aparece no hover/tap da bolha do user
2. Ao clicar, troca o conteúdo da bolha por um TextField editável com o texto original
3. Ao confirmar, deleta mensagens subsequentes (assistant + user posteriores) e reenvia
4. Controller: novo método `editAndResend(conversationId, messageId, newText)`  
**Complexidade:** Média — precisa deletar mensagens do banco e re-perguntar.

---

## Sprint C — Baixa Prioridade (polish visual)

### C1. Separador de data
**Arquivo:** `lib/features/chat/chat_screen.dart` → `_buildMessageList()`  
**Mudança:** Antes de renderizar cada mensagem, verificar se a data mudou em relação à anterior. Se sim, inserir um widget divider com texto ("Hoje", "Ontem", ou "DD/MM/YYYY").

### C2. Ícone do motor
**Arquivo:** `lib/features/chat/widgets/message_bubble.dart`  
**Mudança:** Ao lado do texto do modelo no footer, adicionar ícone:
- Sonnet/Opus: `Icons.cloud_outlined` (laranja)
- Qwen Local: `Icons.computer_outlined` (verde)

### C3. Transição suave ao trocar conversa
**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Mudança:** Wrap o ListView com `AnimatedSwitcher(duration: 200ms)` usando `_activeConversationId` como key. Dá fade-in ao trocar.

### C4. Empty state de conversa nova
**Arquivo:** `lib/features/chat/chat_screen.dart` → `_buildMessageList()`  
**Mudança:** Quando `_messages.isEmpty && !_isStreaming`, mostrar o mesmo empty state que já existe (ícone + prompt starters), mas dentro do painel de chat (não só quando não há conversa selecionada).

### C5. Feedback tátil no like/dislike
**Arquivo:** `lib/features/chat/widgets/message_bubble.dart` → `_FeedbackButton`  
**Mudança:** Wrap o Icon com `AnimatedScale` — ao clicar, scale para 1.3 por 150ms, depois volta a 1.0. Cor transition já acontece pelo rebuild.

---

## Ordem de Execução

1. A1 (citação real) — independente
2. A2 (retry) — independente
3. A3 (scroll-to-bottom) — independente
4. B1 (input focus) — independente
5. C1 (separador data) — independente
6. C2 (ícone motor) — independente
7. C4 (empty state conversa) — independente
8. C5 (feedback tátil) — independente
9. C3 (transição suave) — independente
10. B2 (editar mensagem) — mais complexo, por último

---

## Verificação

Após cada item:
- `flutter analyze` limpo
- `flutter test` — todos passando
- Commit individual com descrição do que mudou

Após todos:
- Fragmento de changelog
- Build macOS para confirmar
