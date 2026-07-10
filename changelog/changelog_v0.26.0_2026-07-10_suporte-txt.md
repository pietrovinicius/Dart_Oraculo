## [0.26.0] - 2026-07-10

### Adicionado
- **chat_screen.dart**: Suporte a arquivos `.txt` no RAG — file picker, drag & drop e importação por lote.
- **chat_screen.dart**: `.txt` roteado para `ingestMarkdown` (texto plano é subset válido de markdown).
- **chat_screen.dart**: Drag & drop de `.txt` exibe dialog de destino (Biblioteca vs Conversa), mesmo comportamento de `.md`.

### Alterado
- **chat_screen.dart**: Overlay de arraste atualizado: "Solte a imagem, .md ou .txt aqui".
- **chat_screen.dart**: Mensagem de erro de formato inválido inclui TXT na lista de aceitos.
