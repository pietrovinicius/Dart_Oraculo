## [0.21.0] - 2026-07-05

### Adicionado
- **app_colors.dart**: Paleta light completa (background, surface, text, divider).
- **app_theme.dart**: `AppTheme.light` — ThemeData completo para modo claro.
- **theme_notifier.dart**: ChangeNotifier que gerencia ThemeMode com persistência no Keychain.
- **app.dart**: MaterialApp com `theme` + `darkTheme` + `themeMode` reativo via ThemeNotifier.
- **secure_storage_service.dart**: Métodos `readRaw`/`writeRaw` para acesso genérico ao Keychain.
- **settings_screen.dart**: Seção "Aparência" com RadioListTile — Claro / Escuro / Sistema.

### Alterado
- **app.dart**: Convertido de StatelessWidget para StatefulWidget para hospedar ThemeNotifier.
- Default mantido como escuro (comportamento existente preservado).
