## [0.15.0] - 2026-07-05

### Adicionado
- **image_attachment.dart**: Modelo ImageAttachment (bytes, mediaType, path)
- **image_resize_service.dart**: Redimensiona imagens para ≤1568px no lado maior antes do envio
- **clipboard_image_service.dart**: Wrapper sobre pasteboard para leitura de imagem via Cmd+V
- **chat_input.dart**: Botão 📎 para anexar imagem + Cmd+V cola imagem do clipboard + preview com ✕
- **chat_screen.dart**: Integração completa — resize, salva em AppSupport/chat_images/, texto default se vazio
- **anthropic_service.dart**: Content blocks de imagem base64 posicionados antes do texto na API
- **ollama_service.dart**: Campo `images` com base64 no body para suporte multimodal qwen3.5
- **generation_service.dart**: Param `List<ImageAttachment>?` na interface streamResponse
- **chat_controller.dart**: Param `ImageAttachment?` em askQuestion, persiste image_path
- **message.dart**: Campo `imagePath` (String?) para persistência do caminho da imagem
- **message_bubble.dart**: Renderiza miniatura da imagem acima do texto quando imagePath presente
- **migrations.dart**: Migration v5 — `ALTER TABLE messages ADD COLUMN image_path TEXT`
- **pubspec.yaml**: +image ^4.0.0, +pasteboard ^0.5.0, +uuid ^4.0.0

### Alterado
- **app_config.dart**: databaseVersion bumped de 4 para 5
- **database_helper.dart**: onCreate usa allV5, onUpgrade inclui bloco oldVersion < 5
