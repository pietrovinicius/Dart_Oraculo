## [0.13.2] - 2026-07-04

### Corrigido
- **lib/features/chat/widgets/message_bubble.dart**: mensagens do usuário agora usam `SelectableText` em vez de `Text` — permite selecionar e copiar.
- **lib/features/chat/chat_screen.dart**: `SelectionArea` envolve o `ListView` de mensagens — permite selecionar texto entre múltiplas bolhas e copiar com Cmd+C.
- **lib/core/services/ollama_service.dart**: timeout aumentado de 2 minutos para 10 minutos — modelo local com muito contexto pode levar vários minutos.
- **lib/core/config/app_config.dart**: `appVersion` corrigido para `0.13.2`.

### Adicionado
- **lib/features/chat/chat_screen.dart**: cronômetro sutil no indicador "Pensando..." — exibe tempo real (`Pensando... 5s`, `Pensando... 1m 23s`), atualiza a cada segundo, para quando o primeiro token chega. Inspirado no Claude Desktop.
