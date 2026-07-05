## [0.15.0] - 2026-07-05

### Corrigido
- **chat_input.dart**: Regressão Cmd+V — CallbackShortcuts consumia evento impedindo paste de texto. Agora usa Focus(onKeyEvent) que retorna ignored, verificando clipboard em paralelo.

### Adicionado
- **chat_input_image_test.dart**: Widget test cobrindo Cmd+V com imagem (anexo) e sem imagem (texto cola normal).
- **message_bubble_image_test.dart**: Widget test cobrindo miniatura presente/ausente conforme imagePath.
