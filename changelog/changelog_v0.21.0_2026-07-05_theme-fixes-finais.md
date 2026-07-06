## [0.21.0] - 2026-07-05

### Corrigido
- **app_text_styles.dart**: Removidas cores hardcoded dos TextStyles — agora herdam do Theme (visíveis em light e dark).
- **chat_screen.dart**: ~40 refs AppColors migradas para Theme.of(context) (background, surface, divider, text).
- **sidebar.dart**: Surface, divider, text colors dinâmicos. surfaceContainerLow em light para separação visual.
- **message_bubble.dart**: Bolha assistant, code block, action buttons usam cores do tema.
- **citation_strip.dart**: Fundo e chips de citação usam surfaceContainerHighest + dividerColor do tema.
- **sidebar.dart**: Dropdown coleção com cor onSurface — "Geral" legível em light.
- **chat_screen.dart**: Dropdown modelo com cor onSurface — "Sonnet" legível em light.
- **settings_screen.dart**: Background usa scaffoldBackgroundColor dinâmico.
