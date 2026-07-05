## [0.19.0] - 2026-07-05

### Corrigido
- **secure_storage_service.dart**: Adicionado `accessibility: KeychainAccessibility.first_unlock` para evitar prompt de senha do macOS a cada acesso ao Keychain em dev sem code signing.
- **chat_screen.dart**: Guard `positions.length == 1` em `_scrollToBottom()` — evita crash "ScrollController attached to multiple scroll views" causado pelo AnimatedSwitcher durante transição de conversa.
