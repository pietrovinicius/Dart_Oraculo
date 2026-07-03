## [0.6.0] - 2026-07-03

### Adicionado
- **lib/features/chat/chat_screen.dart**: tela principal completa — sidebar retrátil, painel de chat com mensagens, toolbar com seletor de modelo (Sonnet 5 / Opus 4.8), toggle sidebar, importação de PDF, estado vazio, tratamento de erro da API.
- **lib/features/chat/widgets/message_bubble.dart**: bolha de mensagem estilizada com alinhamento por role, cor diferenciada user/assistant, exibição do modelo usado.
- **lib/features/chat/widgets/citation_strip.dart**: faixa de citação com chips de documento e página, exibida abaixo de cada resposta do assistant.
- **lib/features/chat/widgets/chat_input.dart**: campo de texto com envio por botão ou Enter, desabilitado durante loading.
- **lib/features/chat/widgets/sidebar.dart**: lista de conversas com seleção, delete, botão nova conversa, e seção de documentos com contagem.
- **test/widget/chat_screen_test.dart**: 8 widget tests cobrindo MessageBubble (alinhamento, modelo), CitationStrip (vazio, chips), ChatInput (envio, vazio), Sidebar (lista, vazio).
