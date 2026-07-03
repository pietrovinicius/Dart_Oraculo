# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Visão Geral do Projeto

**Dart Oráculo** é um app pessoal de RAG (Retrieval-Augmented Generation) construído em Flutter, sem backend. O usuário carrega PDFs, o app indexa o conteúdo localmente via SQLite/FTS5, e responde perguntas via chat usando a API da Anthropic (Sonnet 5 padrão, Opus 4.8 opcional).

- **Plataforma primária:** macOS (MVP), depois Android e iOS com mesma base de código
- **Sem backend:** toda persistência local, único serviço externo é `api.anthropic.com`
- **Peça de portfólio:** segue TDD, commits convencionais em português, design de alta qualidade

## Status Atual

Projeto em **fase de design** — documentação de especificação e design pronta em `design/`, sem código fonte implementado ainda.

## Comandos de Desenvolvimento

```bash
# Flutter SDK local (quando disponível)
../../flutter/bin/flutter pub get
../../flutter/bin/flutter run -d macos
../../flutter/bin/flutter analyze
../../flutter/bin/flutter test

# Rodar teste específico
../../flutter/bin/flutter test test/unit/nome_do_teste_test.dart
```

## Arquitetura (5 Camadas, Binário Único)

```
┌─────────────────────────────────────────┐
│  UI (Flutter)                           │
├─────────────────────────────────────────┤
│  Camada de Geração                      │  → POST api.anthropic.com/v1/messages (streaming)
├─────────────────────────────────────────┤
│  Camada de Recuperação                  │  → FTS5 query → top-N chunks → monta prompt
├─────────────────────────────────────────┤
│  Camada de Ingestão                     │  → PDF → texto → markdown → chunks → SQLite
├─────────────────────────────────────────┤
│  Camada de Persistência                 │  → SQLite (drift ou sqflite+ffi) + FTS5
├─────────────────────────────────────────┤
│  Camada de Segurança                    │  → flutter_secure_storage + local_auth
└─────────────────────────────────────────┘
```

## Modelo de Dados (SQLite)

- `documents` — metadados do PDF importado (filename, source_path, imported_at)
- `chunks` — fragmentos de texto com referência a documento e página
- `chunks_fts` — tabela virtual FTS5 espelhando `chunks.content` para busca BM25
- `conversations` — histórico de conversas
- `messages` — mensagens user/assistant com modelo usado

## Fluxos Principais

1. **Ingestão:** file_picker → extração texto PDF → normalização markdown → chunking → gravação em `documents`/`chunks` → trigger atualiza `chunks_fts`
2. **Pergunta:** input do usuário → consulta FTS5 → top-N chunks → montagem de prompt (contexto + histórico recente) → API Anthropic (streaming) → resposta no chat → persistência em `messages`
3. **Gestão de custo:** resumo compacto sempre no prompt (hot cache) + chunks completos sob demanda via FTS5

## Stack Técnica (Candidatas)

| Necessidade | Pacote |
|---|---|
| Persistência | `drift` ou `sqflite` + `sqflite_common_ffi` |
| Busca texto completo | FTS5 nativo do SQLite |
| Extração PDF | `syncfusion_flutter_pdf` |
| Segurança da chave | `flutter_secure_storage` |
| Auth local (biometria) | `local_auth` |
| HTTP (API Anthropic) | `http` ou `dio` (chamada direta, sem LangChain na v1) |
| Seleção de arquivo | `file_picker` |
| Markdown no chat | `flutter_markdown` |

## Decisões Arquiteturais

- **Sem embeddings na v1** — busca lexical FTS5/BM25 até se provar insuficiente com dados reais
- **Cliente HTTP direto** — sem LangChain.dart na Fase 1; revisitar se lógica de encadeamento crescer
- **Cada instalação isolada** — sem sincronização entre dispositivos
- **PDF texto nativo apenas** — OCR de scanned PDF fora de escopo da v1

## Roadmap

1. **Fase 1 (MVP macOS):** Ingestão PDF + FTS5 + chat funcional + armazenamento seguro
2. **Fase 2:** Portabilidade Android/iOS (mesma base de código)
3. **Fase 3:** Grafo visual de notas e tags via `graphview`
4. **Fase 4:** Avaliação de busca semântica (Voyage / on-device / manter lexical)

## Design Visual

- Paleta escura com acento laranja — detalhes em `design/design.md`
- Tipografia intencional: display serifada, corpo sans geométrica, técnica monoespaçada
- Três telas core: bloqueio (biometria), principal (chat + documentos), configurações
- Anti-template: interface memorável, não genérica

## Referências de Documentação

- `design/oraculo-especificacao-dev.md` — especificação técnica completa
- `design/design.md` — direção visual, paleta, tipografia, wireframes
- `design/design_Dart_Oraculo.pdf` — design visual em PDF
