## [0.20.0] - 2026-07-05

### Corrigido
- **chat_screen.dart**: Removido AnimatedSwitcher do painel de mensagens — causava crash "ScrollController attached to multiple scroll views" ao trocar conversa.
- **chat_screen.dart**: FAB scroll-to-bottom reposicionado (bottom: 80) para não sobrepor última mensagem.

### Adicionado
- **chat_screen.dart**: Confirmação AlertDialog antes de excluir conversa ("Esta ação não pode ser desfeita").
- **message_bubble.dart**: Spinner de loading durante verificação de fidelidade no like (substitui ícone thumb_up enquanto verifica).
- **message_bubble.dart**: Param `isVerifying` para controlar estado visual do feedback.
