## [0.1.0] - 2026-07-03

### Adicionado
- **pubspec.yaml**: dependências completas da Fase 1 (sqflite, sqflite_common_ffi, syncfusion_flutter_pdf, flutter_secure_storage, local_auth, http, file_picker, flutter_markdown, path_provider, intl).
- **analysis_options.yaml**: lint rules rigorosas com flutter_lints.
- **.gitignore**: atualizado para Flutter + macOS + IDE + coverage.
- **lib/core/theme/**: paleta escura com acento laranja (app_colors), tipografia 3 famílias (app_text_styles), ThemeData unificado (app_theme).
- **lib/core/config/**: rotas nomeadas (app_routes), constantes globais e config da API Anthropic (app_config).
- **lib/core/constants/storage_keys.dart**: chaves para flutter_secure_storage.
- **lib/core/database/migrations.dart**: schema SQLite completo (documents, chunks, chunks_fts FTS5, conversations, messages) com triggers de sincronização.
- **lib/core/database/database_helper.dart**: singleton SQLite via sqflite_common_ffi.
- **lib/main.dart**: entry point com inicialização FFI.
- **lib/app.dart**: MaterialApp com tema escuro e rotas.
- **lib/features/auth/lock_screen.dart**: stub da tela de bloqueio com biometria.
- **lib/features/chat/chat_screen.dart**: stub da tela principal.
- **lib/features/settings/settings_screen.dart**: stub da tela de configurações.
- **macos/**: runner nativo macOS gerado pelo Flutter.
- **test/unit/app_smoke_test.dart**: teste mínimo de instanciação do app.
- **CLAUDE.md**: regras de execução do projeto.
- **AGENTS.md**: 11 decisões arquiteturais com justificativa.
- **docs/superpowers/specs/2026-07-03-dart-oraculo-mvp-design.md**: spec de design aprovada.
