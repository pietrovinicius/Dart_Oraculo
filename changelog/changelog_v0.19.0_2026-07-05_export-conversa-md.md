## [0.19.0] - 2026-07-05

### Adicionado
- **chat_controller.dart**: Método `exportConversationAsMarkdown()` — gera markdown completo com cabeçalho, mensagens, modelo, fontes citadas, nota de imagem anexada.
- **chat_controller.dart**: `_buildCitationLabels()` — diferencia citações de documento original vs resposta promovida.
- **sidebar.dart**: Opção "Exportar .md" no menu de contexto de cada conversa (ícone download).
- **chat_screen.dart**: `_exportConversation()` — file picker save dialog + feedback sucesso/erro.
- **export_conversation_test.dart**: 3 testes unitários (formato, imagem, citações diferenciadas).
