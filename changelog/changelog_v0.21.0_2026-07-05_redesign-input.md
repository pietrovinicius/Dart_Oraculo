## [0.21.0] - 2026-07-05

### Alterado
- **chat_input.dart**: Layout redesenhado inspirado no Claude Desktop:
  - Seletor de modelo movido para dentro do input (ao lado do send)
  - Mic reposicionado ao lado do botão enviar
  - Botão enviar com fundo laranja arredondado + ícone seta (↑)
  - Disclaimer "Dart Oráculo é uma IA e pode cometer erros" abaixo do input
- **chat_screen.dart**: Dropdown de modelo removido da toolbar (agora vive no input).
- **chat_screen.dart**: Passa selectedModel + onModelChanged ao ChatInput.
