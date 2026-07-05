## [0.16.0] - 2026-07-05

### Adicionado
- **speech_service.dart**: Wrapper sobre speech_to_text, injetável e mockável. Idioma via locale do sistema.
- **chat_input.dart**: Botão de microfone para ditado por voz. Resultado parcial popula campo em tempo real. Tap novamente para parar.
- **chat_input.dart**: Tratamento de permissão negada com toast de erro claro.
- **Info.plist**: NSSpeechRecognitionUsageDescription + NSMicrophoneUsageDescription.
- **entitlements**: com.apple.security.device.audio-input em Debug e Release.
- **pubspec.yaml**: +speech_to_text ^7.0.0
- **speech_service_test.dart**: 5 testes unitários (initialize, start, stop, resultado, indisponível).
- **chat_input_speech_test.dart**: 3 widget tests (escuta + popula, permissão negada, toggle).

### Verificação manual pendente
- [ ] Digitar texto funciona normalmente
- [ ] Cmd+V texto cola normalmente
- [ ] Cmd+V imagem anexa normalmente
- [ ] Botão mic inicia/para ditado com transcrição no campo
