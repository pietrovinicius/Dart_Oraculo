## [0.19.0] - 2026-07-05

### Corrigido
- **chat_screen.dart**: Debounce no botão like — impede cliques múltiplos durante verificação de fidelidade. Lock por messageId evita chamadas simultâneas.
- **chat_screen.dart**: Feedback visual imediato — botão reflete estado antes da verificação terminar.
- **chat_screen.dart**: Dialog de confirmação com `barrierDismissible: false` — impede dismiss acidental durante verificação.
