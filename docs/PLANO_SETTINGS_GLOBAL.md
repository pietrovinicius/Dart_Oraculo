# Plano: Migrar Toggles e Constantes para Settings Global

**Versão alvo:** 0.25.0  
**Data:** 2026-07-09  
**Escopo:** Mover todas as configurações dispersas para `settings_screen.dart` como config global persistida via `SecureStorageService`.

---

## Resumo das Mudanças

| # | Config | Hoje | Destino |
|---|--------|------|--------|
| 1 | Verificar fidelidade (`verify_before_promote`) | Toggle por coleção (dialog ⚙️) | Settings global |
| 2 | Histórico de mensagens (`maxHistoryMessages`) | Constante fixa `10` em `app_config.dart` | Settings global (slider 5–30) |
| 3 | Máx. chunks por query (`maxChunksPerQuery`) | Constante fixa `10` em `app_config.dart` | Settings global (slider 3–20) |
| 4 | Tamanho máx. chunk (`chunkMaxTokens`) | Constante fixa `500` em `app_config.dart` | Settings global (slider 200–1000) |

---

## Etapas de Implementação

### Etapa 1 — Mover "Verificar fidelidade" para Settings

**Arquivos:**
- `lib/features/settings/settings_screen.dart` — adicionar toggle
- `lib/features/chat/chat_controller.dart` — ler de SecureStorage em vez de coluna da coleção
- `lib/features/chat/chat_screen.dart` — remover toggle do dialog de coleção

**Lógica:**
1. `settings_screen.dart`: novo `_buildFidelitySection()` com `SwitchListTile`
2. Persiste via `writeRaw('verify_before_promote_enabled', 'true'|'false')` — default `true`
3. `chat_controller.dart:_checkAndPromote()`: substitui leitura da coluna `collections.verify_before_promote` por `SecureStorageService().readRaw('verify_before_promote_enabled')`
4. `chat_screen.dart`: remove `SwitchListTile` de fidelidade do dialog de coleção

**Testes:**
- Teste unitário: `_checkAndPromote` respeita config global
- Teste unitário: skip quando toggle OFF

---

### Etapa 2 — Expor `maxHistoryMessages` como configurável

**Arquivos:**
- `lib/features/settings/settings_screen.dart` — slider "Histórico de conversa"
- `lib/features/chat/chat_controller.dart` — ler valor de SecureStorage com fallback para `AppConfig.maxHistoryMessages`

**Lógica:**
1. `settings_screen.dart`: novo `_buildAdvancedSection()` com Slider (5–30, step 5, default 10)
2. Persiste via `writeRaw('max_history_messages', '$value')`
3. `chat_controller.dart:askQuestion()` (linha ~274): `int.tryParse(await storage.readRaw('max_history_messages') ?? '') ?? AppConfig.maxHistoryMessages`

**UI:**
- Label: "Mensagens de contexto"
- Subtitle: "Quantas mensagens anteriores enviar ao modelo (mais = mais contexto, mais tokens)"
- Exibe valor atual ao lado do slider

---

### Etapa 3 — Expor `maxChunksPerQuery` como configurável

**Arquivos:**
- `lib/features/settings/settings_screen.dart` — slider "Chunks por busca"
- `lib/core/services/fts_service.dart` — aceitar `limit` dinâmico
- `lib/features/chat/chat_controller.dart` — passar limit lido de SecureStorage

**Lógica:**
1. `settings_screen.dart`: Slider (3–20, step 1, default 10) no mesmo `_buildAdvancedSection()`
2. Persiste via `writeRaw('max_chunks_per_query', '$value')`
3. `chat_controller.dart`: lê config e passa como `limit:` para `ftsService.search()`

**UI:**
- Label: "Chunks de contexto"
- Subtitle: "Máximo de trechos recuperados por pergunta (mais = respostas mais completas, mais tokens)"

---

### Etapa 4 — Expor `chunkMaxTokens` como configurável

**Arquivos:**
- `lib/features/settings/settings_screen.dart` — slider "Tamanho do chunk"
- `lib/core/services/chunking_service.dart` — já aceita `maxTokensPerChunk` no constructor
- `lib/features/documents/document_service.dart` — passar valor lido de SecureStorage
- `lib/features/chat/chat_screen.dart` — onde cria `DocumentService`, passar config

**Lógica:**
1. `settings_screen.dart`: Slider (200–1000, step 50, default 500) no `_buildAdvancedSection()`
2. Persiste via `writeRaw('chunk_max_tokens', '$value')`
3. `document_service.dart`: lê na ingestão e passa ao `ChunkingService`
4. **Nota:** não afeta docs já indexados — apenas novos uploads

**UI:**
- Label: "Tamanho do chunk"
- Subtitle: "Tokens por trecho na indexação (menor = mais preciso, maior = mais contexto por chunk). Afeta apenas novos documentos."

---

## Layout Final em Settings

```
┌─────────────────────────────────┐
│ Configurações                   │
├─────────────────────────────────┤
│ 🔑 Chave de API da Anthropic    │
│ 🤖 Modelo padrão                │
│ 🧠 Conhecimento geral      [SW] │
│ ✅ Verificar fidelidade    [SW] │
│ 🎨 Aparência                    │
│ 🔍 Zoom de texto                │
│ 🔐 Autenticação local      [SW] │
│ ⚙️  Avançado                     │
│   ├─ Mensagens de contexto [SL] │
│   ├─ Chunks por busca      [SL] │
│   └─ Tamanho do chunk      [SL] │
└─────────────────────────────────┘
[SW] = SwitchListTile  [SL] = Slider
```

---

## Chaves de SecureStorage (novas)

| Chave | Tipo | Default | Descrição |
|-------|------|---------|----------|
| `verify_before_promote_enabled` | `'true'\|'false'` | `'true'` | Checagem de fidelidade antes de promover |
| `max_history_messages` | `'5'...'30'` | `'10'` | Msgs de histórico enviadas ao modelo |
| `max_chunks_per_query` | `'3'...'20'` | `'10'` | Chunks FTS5 recuperados por pergunta |
| `chunk_max_tokens` | `'200'...'1000'` | `'500'` | Tokens máx por chunk na indexação |

---

## Ordem de Execução

1. Etapa 1 (verificar fidelidade) — menor risco, padrão idêntico ao "Conhecimento geral"
2. Etapa 2 (histórico) — impacto isolado em chat_controller
3. Etapa 3 (chunks/query) — impacto em fts_service + chat_controller
4. Etapa 4 (chunk size) — impacto em document_service (apenas ingestão futura)

---

## Riscos e Mitigações

| Risco | Mitigação |
|-------|----------|
| Usuário define chunk_max_tokens=200 e perde contexto | Subtitle explica trade-off |
| Mudança de chunk_max_tokens não afeta docs existentes | Warning no subtitle |
| maxHistoryMessages=30 estoura tokens da API | Truncamento já existe no prompt |
| Config lida a cada pergunta (SecureStorage é I/O) | Keychain macOS é rápido (~1ms), não é gargalo |

---

## Versionamento

- Bump: `0.24.0` → `0.25.0` (nova funcionalidade exposta ao usuário)
- Fragment: `changelog/changelog_v0.25.0_2026-07-09_settings-global-avancado.md`
