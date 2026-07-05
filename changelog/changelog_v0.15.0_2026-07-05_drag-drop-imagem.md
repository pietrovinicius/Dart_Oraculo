## [0.15.0] - 2026-07-05

### Adicionado
- **chat_screen.dart**: Drag & drop de imagem do Finder — DropTarget envolvendo painel de chat.
- **chat_screen.dart**: Overlay visual sutil (laranja transparente + ícone) durante arraste.
- **chat_screen.dart**: Validação de extensão (jpg, jpeg, png, gif, webp) — rejeita com toast.
- **pubspec.yaml**: +desktop_drop ^0.4.0
- **chat_screen_drop_test.dart**: Widget test confirmando DropTarget na árvore.

### Verificação manual pendente
- [ ] Scroll da lista de mensagens funciona com DropTarget
- [ ] Seleção de texto nas bolhas funciona
- [ ] Cmd+V texto cola normalmente
- [ ] Cmd+V imagem anexa normalmente

*Nota: Testes manuais devem ser executados pelo usuário com app rodando antes de considerar entregue.*
