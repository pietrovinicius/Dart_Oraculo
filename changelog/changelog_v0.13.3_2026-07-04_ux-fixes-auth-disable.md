## [0.13.3] - 2026-07-04

### Corrigido
- **lib/features/chat/chat_screen.dart**: removido `SelectionArea` do ListView — conflitava com scroll, gestos de botões e input. Cada bolha é selecionável independentemente (SelectableText para user, MarkdownBody selectable para assistant).
- **lib/features/chat/widgets/chat_input.dart**: substituído `KeyboardListener` por `CallbackShortcuts` — não intercepta mais Cmd+V/Cmd+C. Enter envia, Shift+Enter quebra linha, atalhos do sistema funcionam normalmente.
- **lib/core/services/ollama_service.dart**: timeout aumentado de 2 minutos para 10 minutos — modelo local com muito contexto pode levar vários minutos.
- **lib/features/chat/chat_screen.dart**: cronômetro sutil "Pensando... Xs" / "Pensando... Xm Ys" atualiza a cada segundo enquanto aguarda resposta.
- **pubspec.yaml**: version bumped para 0.13.2+1 (corrige rodapé que mostrava 0.11.2).

### Adicionado
- **lib/features/auth/lock_screen.dart**: flag `SKIP_AUTH` via `--dart-define` para bypass de biometria em testes automatizados. ADR-015 em AGENTS.md.
- **docs/auditoria_v0.13.2_2026-07-04.md**: relatório completo de auditoria UX + qualidade RAG (21 fluxos, 17 aprovados, 3 com ressalva, 1 reprovado).

### Alterado
- **lib/features/auth/lock_screen.dart**: autenticação biométrica desabilitada temporariamente via `_authDisabled = true`. Flag com TODO para reativação futura. App abre direto na home.
