# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Visão Geral

**Dart Oráculo** — app Flutter desktop (macOS) de RAG pessoal. Carrega PDFs, indexa localmente via SQLite/FTS5, conversa com Claude (Sonnet 5 / Opus 4.8) sobre o conteúdo. Sem backend, único serviço externo é `api.anthropic.com`.

## Comandos

```bash
# Dependências
flutter pub get

# Rodar no macOS
flutter run -d macos

# Análise estática
flutter analyze

# Todos os testes
flutter test

# Teste específico
flutter test test/unit/services/fts_service_test.dart

# Coverage
flutter test --coverage
```

## Estrutura do Projeto

```
lib/
├── main.dart / app.dart
├── core/
│   ├── config/          # app_config, app_routes
│   ├── constants/       # storage_keys
│   ├── database/        # database_helper, migrations (schema + FTS5 triggers)
│   ├── services/        # anthropic, pdf, chunking, fts, secure_storage
│   └── theme/           # colors, text_styles, theme
├── features/
│   ├── auth/            # lock_screen, auth_service
│   ├── chat/            # chat_screen, chat_controller, widgets/, models/
│   ├── documents/       # document_service, models/
│   └── settings/        # settings_screen, settings_controller
└── widgets/             # globais reutilizáveis

test/
├── unit/services/       # testes de cada service
├── unit/features/       # testes de controllers
├── widget/              # testes de tela
└── integration/         # fluxo RAG end-to-end
```

## Convenções

- **TDD obrigatório:** RED → GREEN → REFACTOR. Nenhum código de produção sem teste falhando antes.
- **Commits:** Conventional Commits em português — `tipo(escopo): descrição vX.Y.Z`
- **Changelog (OBRIGATÓRIO):** Todo commit que altere comportamento, corrija bug, ou adicione feature DEVE incluir um fragment em `changelog/`. Nome: `changelog_vX.Y.Z_YYYY-MM-DD_slug.md`. Formato Keep a Changelog. Nunca editar CHANGELOG.md diretamente. Commitar fragment junto com o código. Sem exceção.
- **State:** ChangeNotifier para controllers, setState para UI efêmera. Sem package externo.
- **Imutabilidade:** Sempre criar novos objetos, nunca mutar existentes.
- **Arquivos:** < 400 linhas ideal, 800 max. Funções < 50 linhas.
- **Push:** NÃO executar `git push` — feito manualmente pelo usuário.

## Stack Definida (v1)

| Necessidade | Pacote |
|---|---|
| Persistência | sqflite + sqflite_common_ffi |
| Busca | FTS5 nativo SQLite (BM25) |
| Extração PDF | syncfusion_flutter_pdf |
| Segurança | flutter_secure_storage (Keychain macOS) |
| Auth local | local_auth |
| HTTP | http (chamada direta, sem framework) |
| File picker | file_picker |
| Markdown | flutter_markdown |

## Modelo de Dados

5 tabelas: `documents`, `chunks`, `chunks_fts` (virtual FTS5), `conversations`, `messages`.

`messages.chunks_used` armazena IDs dos chunks usados para rastreabilidade de citação.

Triggers mantêm `chunks_fts` sincronizado com `chunks`.

## Arquitetura (5 Camadas)

```
UI → Geração (API Anthropic streaming) → Recuperação (FTS5 BM25)
   → Ingestão (PDF → markdown → chunks) → Persistência (SQLite) + Segurança
```

## Decisões Arquiteturais

Ver `AGENTS.md` para lista completa com justificativas.

Resumo: sem embeddings, sem LangChain, sem state management package, cliente HTTP direto, estrutura por feature.

## Design Visual

- Paleta escura + acento laranja — `design/design.md`
- Tipografia: display serifada, corpo sans geométrica, técnica monoespaçada
- Anti-template: interface memorável, não genérica

## Hierarquia de Fontes de Verdade

1. `design/oraculo-especificacao-dev.md` — arquitetura, stack, schema, fluxos
2. `design/design.md` — paleta, tipografia, telas
3. `design/screenshots/*.png` — referência visual de layout apenas
4. `design/design_Dart_Oraculo.pdf` — material de apoio

Ignorar qualquer menção a busca vetorial/semântica em screenshots — a arquitetura real é FTS5 lexical.
