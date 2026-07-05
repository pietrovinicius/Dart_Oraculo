## [0.20.0] - 2026-07-05

### Corrigido
- **chat_controller.dart**: Limite de tamanho de context attachments agora é pela soma total combinada (≤ maxContextCharsPerChunk do motor), não por anexo isolado. Três docs de 20k chars não somam 60k — trunca ao atingir 20k total.

### Adicionado
- **chat_controller.dart**: Log detalhado: `N/M anexos injetados (X/Y chars)` mostra quanto do limite foi usado.
- **chat_controller.dart**: Warning quando anexo é ignorado por limite atingido.
- **context_attachment_chip_test.dart**: Widget test com WidgetTester — tap no ✕ chama callback de remoção.
