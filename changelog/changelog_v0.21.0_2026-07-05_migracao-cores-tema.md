## [0.21.0] - 2026-07-05

### Corrigido
- **chat_screen.dart**: Migrado ~20 referências de AppColors hardcoded para Theme.of(context) — background, surface, divider, textSecondary, textMuted, surfaceLight.
- **sidebar.dart**: Migrado surface, divider, textPrimary, textSecondary, textMuted, surfaceLight para tema dinâmico.
- **chat_input.dart**: Container surface usa tema dinâmico.
- **message_bubble.dart**: surfaceLight e textMuted usam tema dinâmico.
- **settings_screen.dart**: Background usa scaffoldBackgroundColor do tema.

### Resultado
- Modo claro agora mostra cores claras reais em todos os painéis principais.
- Sidebar, toolbar, input, bolhas e dialogs respondem ao tema.
