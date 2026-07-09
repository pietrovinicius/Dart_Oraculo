# Regras de Negócio — Dart Oráculo

Auditoria completa das regras implementadas no código-fonte (v0.25.0).

---

## 1. SEGURANÇA

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| S1 | API key armazenada exclusivamente no macOS Keychain via `flutter_secure_storage` — nunca em texto plano | `lib/core/services/secure_storage_service.dart` | ~30-40 |
| S2 | Falha de leitura/escrita no Keychain lança `SecureStorageException` (surfaça erro, nunca fallback silencioso) | `lib/core/services/secure_storage_service.dart` | ~75-95 |
| S3 | Autenticação biométrica obrigatória na abertura do app (Touch ID / senha do sistema via `local_auth`) | `lib/features/auth/lock_screen.dart` | ~40 |
| S4 | Bypass de biometria apenas via flag de compilação `SKIP_AUTH=true` (para testes automatizados) | `lib/features/auth/lock_screen.dart` | ~30 |
| S5 | Biometria configurável por toggle em Settings — se desabilitada, auth retorna `notConfigured` e não bloqueia | `lib/features/auth/auth_service.dart` | ~38-45 |
| S6 | `AuthenticationOptions(stickyAuth: true, biometricOnly: false)` — permite fallback para senha do sistema | `lib/features/auth/auth_service.dart` | ~55 |
| S7 | API key nunca logada — log exibe apenas `[SET]` ou `null` | `lib/core/services/secure_storage_service.dart` | ~70 |
| S8 | Campo de API key mascarado (`obscureText`) na tela de Settings — não salva se contém `••••` | `lib/features/settings/settings_screen.dart` | ~buildApiKeySection |

---

## 2. DADOS / PERSISTÊNCIA

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| D1 | SQLite local como único repositório — sem backend remoto | `lib/core/database/database_helper.dart` | ~20-30 |
| D2 | Schema versionado (v1→v10) com migrations incrementais | `lib/core/database/migrations.dart` | completo |
| D3 | Fresh install cria coleção "Geral" como padrão | `lib/core/database/database_helper.dart` | ~_onCreate |
| D4 | Upgrade v2→v3 faz backfill: cria "Geral" e associa documentos/conversas órfãos | `lib/core/database/database_helper.dart` | ~_onUpgrade oldVersion<3 |
| D5 | Tabela `messages`: CHECK constraint `role IN ('user', 'assistant')` | `lib/core/database/migrations.dart` | ~createMessages |
| D6 | Tabela `message_feedback`: CHECK constraint `value IN ('like', 'dislike')` | `lib/core/database/migrations.dart` | ~createMessageFeedback |
| D7 | FK `chunks.document_id → documents(id)` | `lib/core/database/migrations.dart` | ~createChunks |
| D8 | FK `messages.conversation_id → conversations(id)` | `lib/core/database/migrations.dart` | ~createMessages |
| D9 | FK `message_feedback.message_id → messages(id)` | `lib/core/database/migrations.dart` | ~createMessageFeedback |
| D10 | Coluna `chunks.source_type` DEFAULT `'document'` — diferencia chunks de PDF vs promoted answers | `lib/core/database/migrations.dart` | ~V6 |
| D11 | Coluna `chunks.original_message_id` — rastreabilidade de promoção | `lib/core/database/migrations.dart` | ~V6 |
| D12 | Tabela `conversation_context_attachments` (V8) — documentos de trabalho por conversa | `lib/core/database/migrations.dart` | ~V8 |
| D13 | Coluna `collections.verify_before_promote` DEFAULT 1 (V7) — toggle fidelidade por coleção | `lib/core/database/migrations.dart` | ~V7 |
| D14 | Coluna `collections.web_search_fallback` DEFAULT 0 (V9) — feature desabilitada/removida | `lib/core/database/migrations.dart` | ~V9 |
| D15 | Coluna `collections.general_knowledge_fallback` DEFAULT 0 (V10) — **obsoleta desde v0.24.0**: toggle agora é global via SecureStorage | `lib/core/database/migrations.dart` | ~V10 |
| D16 | Coluna `messages.response_source` TEXT (V10) — registra origem `'rag'|'general'|'web'` | `lib/core/database/migrations.dart` | ~V10 |
| D17 | Coluna `messages.image_path` TEXT (V5) — caminho local de imagem anexada | `lib/core/database/migrations.dart` | ~V5 |
| D18 | Coluna `conversations.pinned` INTEGER DEFAULT 0 (V2) — fixar conversa no topo | `lib/core/database/migrations.dart` | ~V2 |
| D19 | Coluna `documents.description` TEXT (V4) — descrição gerada por IA | `lib/core/database/migrations.dart` | ~V4 |
| D20 | Coluna `documents.collection_id` — documento pertence a uma coleção (V3) | `lib/core/database/migrations.dart` | ~V3 |
| D21 | Coluna `conversations.collection_id` — conversa pertence a uma coleção (V3) | `lib/core/database/migrations.dart` | ~V3 |

---

## 3. CHAT / GERAÇÃO

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| C1 | Streaming token a token — geração nunca é batch/blocking | `lib/core/services/generation_service.dart` | interface |
| C2 | `max_tokens: 4096` para todas as chamadas Anthropic | `lib/core/services/anthropic_service.dart` | ~buildRequestBody |
| C3 | Histórico de conversa limitado às últimas 10 mensagens (`maxHistoryMessages`) | `lib/features/chat/chat_controller.dart` | ~273-276 |
| C4 | Sistema de stop: usuário pode interromper geração a qualquer momento (`_stopRequested`) | `lib/features/chat/chat_screen.dart` | ~69, 750, 1040 |
| C5 | Mensagem do `user` é persistida ANTES de chamar a API — garante registro mesmo se falhar | `lib/features/chat/chat_controller.dart` | ~passo 4 |
| C6 | Mensagem do `assistant` é persistida APÓS streaming completo com `model_used` e `chunks_used` | `lib/features/chat/chat_controller.dart` | ~passo 6 |
| C7 | `response_source` registrado automaticamente: `'rag'` (chunks encontrados), `'general'` (RAG vazio + fallback), `'web'` (desabilitado) | `lib/features/chat/chat_controller.dart` | ~responseSource logic |
| C8 | System prompt personificado: "Você é o Dart Oráculo, assistente de conhecimento pessoal" | `lib/core/services/anthropic_service.dart` | ~buildRequestBody |
| C9 | Duas variantes de prompt: modo estrito (só contexto) vs modo conhecimento geral (permite fallback com aviso visual) | `lib/core/services/anthropic_service.dart` | ~buildRequestBody |
| C10 | Modo estrito: se info não está no contexto → responde "Não encontrei essa informação nos documentos indexados" | `lib/core/services/anthropic_service.dart` | ~instructions strict |
| C11 | Modo geral: fallback sinalizado com `⚠️ Resposta baseada em conhecimento geral do modelo` | `lib/core/services/anthropic_service.dart` | ~instructions geral |
| C12 | Citação obrigatória no prompt: cite documento fonte e página quando usar contexto | `lib/core/services/anthropic_service.dart` | ~instructions |
| C13 | Cite nome quando usar DOCUMENTO DE TRABALHO; cite URL quando usar CONTEXTO WEB | `lib/core/services/anthropic_service.dart` | ~instructions 6-7 |
| C14 | Zoom de texto no chat: range 0.5–2.0, persistível entre sessões via `persist_zoom` | `lib/features/chat/chat_screen.dart` | ~73, 87, 93, 1153-1170 |
| C15 | Exportação de conversa em Markdown | `lib/features/chat/chat_screen.dart` | ~434 (`_exportConversation`) |
| C16 | Renomear conversa e fixar (pin/unpin) disponíveis | `lib/features/chat/chat_screen.dart` | ~424-430 |
| C17 | Exclusão de conversa requer confirmação via dialog | `lib/features/chat/chat_screen.dart` | ~387 (`_deleteConversation`) |

---

## 4. RAG (Retrieval-Augmented Generation)

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| R1 | Busca FTS5 com ranking BM25 — até 10 chunks por query (`maxChunksPerQuery = 10`) | `lib/core/services/fts_service.dart` | ~search(), `lib/core/config/app_config.dart` |
| R2 | Busca filtrada por `collectionId` — só retorna chunks de documentos daquela coleção | `lib/core/services/fts_service.dart` | ~search(collectionId) |
| R3 | Sanitização de query: remoção de stopwords pt-BR + en | `lib/core/services/fts_service.dart` | ~_stopwords, _sanitizeQuery |
| R4 | Priorização de termos técnicos: ALLCAPS ou underscore → usa somente eles na busca | `lib/core/services/fts_service.dart` | ~_isTechnicalTerm, _sanitizeQuery |
| R5 | Termos com underscore viram phrase match (busca exata) | `lib/core/services/fts_service.dart` | ~_sanitizeQuery |
| R6 | Truncamento de chunks no prompt conforme motor: Anthropic=20.000 chars, Ollama=4.000 chars | `lib/core/services/generation_service.dart` | ~maxContextCharsPerChunk |
| R7 | Metadata de fonte injetada no contexto: `[Fonte: filename | p.X | relevância: Y]` | `lib/features/chat/chat_controller.dart` | ~contextBuffer format |
| R8 | Documentos de trabalho (context attachments) injetados APÓS chunks RAG, com limite combinado ≤ maxChars | `lib/features/chat/chat_controller.dart` | ~passo 2b |
| R9 | Documento de trabalho truncado se exceder espaço restante, com aviso de truncamento no texto | `lib/features/chat/chat_controller.dart` | ~"[... documento de trabalho truncado...]" |
| R10 | Instruções da coleção injetadas ANTES do contexto RAG no prompt | `lib/features/chat/chat_controller.dart` | ~"[Instruções da coleção]:" |
| R11 | Conhecimento geral: toggle global lido de `general_knowledge_enabled` em SecureStorage | `lib/features/chat/chat_controller.dart` | ~passo 2c |
| R12 | Chunks de respostas promovidas participam do RAG (source_type='promoted_answer') | `lib/features/chat/chat_controller.dart` | ~_promoteAnswer |
| R13 | FTS5 sincronizado via triggers: INSERT/UPDATE/DELETE em `chunks` reflete em `chunks_fts` | `lib/core/database/migrations.dart` | ~triggers |

---

## 5. PROMOÇÃO E FIDELIDADE

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| P1 | Like em resposta → checagem de fidelidade → promoção como chunk pesquisável | `lib/features/chat/chat_controller.dart` | ~setFeedback |
| P2 | Checagem de fidelidade usa modelo cruzado: Sonnet verifica Opus, vice-versa | `lib/core/services/fidelity_checker.dart` | ~check() |
| P3 | Se modelo é Qwen (local) → skip checagem, promove direto | `lib/features/chat/chat_controller.dart` | ~_checkAndPromote |
| P4 | Toggle `verify_before_promote` por coleção controla se checagem é executada | `lib/features/chat/chat_controller.dart` | ~_checkAndPromote (collectionId check) |
| P5 | Verificador retorna `{"grounded": true}` ou `{"grounded": false, "claims": [...]}` | `lib/core/services/fidelity_checker.dart` | ~systemPrompt |
| P6 | Se não-fundamentada: retorna `FeedbackResult(needsConfirmation: true)` → dialog ao user | `lib/features/chat/chat_controller.dart` | ~_checkAndPromote |
| P7 | User pode forçar promoção mesmo após falha de fidelidade (`forcePromote`) | `lib/features/chat/chat_controller.dart` | ~forcePromote |
| P8 | Promoção cria chunk em documento sintético "Respostas Aprovadas do Oráculo" na coleção | `lib/features/chat/chat_controller.dart` | ~_promoteAnswer |
| P9 | Chunk promovido registra `source_type='promoted_answer'` + `original_message_id` | `lib/features/chat/chat_controller.dart` | ~_promoteAnswer insert |
| P10 | Remoção de like / dislike revoga promoção (deleta chunk associado) | `lib/features/chat/chat_controller.dart` | ~_revokePromotion |
| P11 | Erro do verificador (status != 200) → não bloqueia promoção (fail-open) | `lib/core/services/fidelity_checker.dart` | ~response.statusCode != 200 |
| P12 | Fidelity checker usa `prompt-caching-2024-07-31` (cache ephemeral no system) | `lib/core/services/fidelity_checker.dart` | ~headers anthropic-beta |
| P13 | `max_tokens: 512` para verificador (resposta curta JSON) | `lib/core/services/fidelity_checker.dart` | ~body |
| P14 | Timeout de 30s para chamada do verificador | `lib/core/services/fidelity_checker.dart` | ~.timeout(Duration(seconds: 30)) |

---

## 6. COLEÇÕES

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| COL1 | Coleção "Geral" é obrigatória — não pode ser deletada | `lib/features/collections/collection_service.dart` | ~deleteCollection |
| COL2 | Se "Geral" não existe ao consultar, é recriada (fallback) | `lib/features/collections/collection_service.dart` | ~getDefaultCollection |
| COL3 | Instruções da coleção limitadas a 500 caracteres | `lib/features/collections/collection_service.dart` | ~createCollection (substring 0,500) |
| COL4 | ~~Toggle `verify_before_promote` por coleção~~ — **obsoleto desde v0.25.0**: config agora é global em Settings (`verify_before_promote_enabled` via Keychain) | `lib/features/settings/settings_screen.dart` | ~_buildFidelitySection |
| COL5 | ~~Toggle `general_knowledge_fallback` por coleção~~ — **obsoleto desde v0.24.0**: config agora é global em Settings (`general_knowledge_enabled` via Keychain) | `lib/features/settings/settings_screen.dart` | ~_buildGeneralKnowledgeSection |
| COL6 | Cada coleção possui toggle `web_search_fallback` (default: 0, feature desabilitada) | `lib/core/database/migrations.dart` | ~V9 |
| COL7 | Documentos e conversas sempre pertencem a uma coleção (`collection_id` NOT NULL via backfill) | `lib/core/database/migrations.dart` | ~V3 |
| COL8 | ~~Dialog de configurações por coleção exibia toggles~~ — **obsoleto desde v0.25.0**: todos os toggles migrados para Settings global; dialog apenas informa | `lib/features/chat/chat_screen.dart` | ~230-255 |

---

## 7. INGESTÃO DE DOCUMENTOS

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| I1 | Formatos suportados: PDF, Markdown (.md), CSV, JSON | `lib/features/chat/chat_screen.dart` | ~_importDocument (allowedExtensions) |
| I2 | Limite de 10 arquivos por lote de importação | `lib/features/chat/chat_screen.dart` | ~result.files.length > 10 |
| I3 | Pipeline PDF: extração → normalização markdown → chunking → persistência | `lib/features/documents/document_service.dart` | ~importDocument/ingestMarkdown |
| I4 | Chunking por parágrafo; parágrafos longos subdivididos por sentença | `lib/core/services/chunking_service.dart` | ~chunkPages |
| I5 | Tamanho máximo por chunk: 500 tokens (`chunkMaxTokens`) | `lib/core/config/app_config.dart` | ~chunkMaxTokens |
| I6 | Estimativa de tokens: 1 token ≈ 4 caracteres | `lib/core/services/chunking_service.dart` | ~_estimateTokens |
| I7 | Persistência em batches de 1.000 chunks com yield ao framework entre batches | `lib/features/documents/document_service.dart` | ~_persistDocumentBatch |
| I8 | Descrição gerada por IA após ingestão (se motor disponível) | `lib/features/documents/document_service.dart` | ~_generateDescription |
| I9 | CSV/JSON: dialog para selecionar coluna de agrupamento antes de chunking | `lib/features/chat/chat_screen.dart` | ~_showGroupByDialog |
| I10 | Drag & drop de `.md` exibe dialog de destino: "Biblioteca" (permanente) vs "Conversa" (temporário) | `lib/features/chat/chat_screen.dart` | ~_showMdDestinationDialog |
| I11 | Drag & drop de imagens (jpg/jpeg/png/gif/webp) envia como attachment à mensagem | `lib/features/chat/chat_screen.dart` | ~580-600 |
| I12 | Extensões de imagem reconhecidas: png, jpg, jpeg, gif, webp | `lib/features/chat/chat_screen.dart` | ~ext check (drag handler) |

---

## 8. MOTORES DE GERAÇÃO

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| M1 | Três motores disponíveis: Sonnet (`claude-sonnet-4-6`), Opus (`claude-opus-4-8`), Qwen local | `lib/core/config/app_config.dart` | ~modelos |
| M2 | Modelo padrão: Sonnet | `lib/core/config/app_config.dart` | ~defaultModel |
| M3 | Seleção de modelo em tempo real no chat (troca sem reiniciar conversa) | `lib/features/chat/chat_screen.dart` | ~_updateGenerationService |
| M4 | Ollama: modelo `qwen3.5:latest` em `localhost:11434` | `lib/core/config/app_config.dart` + `lib/core/services/ollama_service.dart` |
| M5 | Ollama rejeita modelos `:cloud` — apenas execução local permitida | `lib/core/services/ollama_service.dart` | ~constructor |
| M6 | Ollama verifica disponibilidade do modelo antes de gerar (`/api/tags`) | `lib/core/services/ollama_service.dart` | ~_checkAvailability |
| M7 | Timeout HTTP geral: 90 segundos | `lib/core/config/app_config.dart` | ~httpTimeout |
| M8 | Interface `GenerationService` abstrai motores (polimorfismo) | `lib/core/services/generation_service.dart` | interface |
| M9 | Se modelo Qwen selecionado, `descriptionService` também usa Ollama (para gerar descrições) | `lib/features/chat/chat_screen.dart` | ~123-124 |
| M10 | Anthropic API versão `2023-06-01` | `lib/core/config/app_config.dart` | ~anthropicVersion |

---

## 9. UI / EXPERIÊNCIA

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| U1 | Tema claro/escuro/sistema selecionável em Settings | `lib/features/settings/settings_screen.dart` | ~_buildThemeSection |
| U2 | Zoom de texto persistível entre sessões (toggle + range 50%-200%) | `lib/features/settings/settings_screen.dart` | ~_buildZoomSection |
| U3 | Conversas fixáveis (pin) no topo da lista | `lib/features/chat/chat_screen.dart` | ~_togglePin |
| U4 | Indicador de streaming com cronômetro de "pensando" | `lib/features/chat/chat_screen.dart` | ~_thinkingStopwatch |
| U5 | Feedback like/dislike por mensagem (toggle: clica de novo remove) | `lib/features/chat/chat_controller.dart` | ~setFeedback |
| U6 | Dialog de confirmação de promoção mostra claims não-fundamentadas | `lib/features/chat/chat_screen.dart` | ~1520 |
| U7 | Importação mostra progresso (% de chunks processados) | `lib/features/chat/chat_screen.dart` | ~_importProgress |
| U8 | Suporte a imagens inline na pergunta (resize + envio como base64) | `lib/features/chat/chat_screen.dart` | ~_sendMessageWithImage |

---

## 10. CONFIGURAÇÃO

| # | Regra | Arquivo | Linha aprox. |
|---|-------|---------|--------------|
| CFG1 | Modelo padrão persistido em Keychain (`StorageKeys.defaultModel`) | `lib/core/services/secure_storage_service.dart` | ~getDefaultModel |
| CFG2 | Toggle de biometria persistido em Keychain (`StorageKeys.biometricEnabled`) | `lib/core/services/secure_storage_service.dart` | ~isBiometricEnabled |
| CFG3 | Toggle global "Conhecimento geral" persistido via `writeRaw('general_knowledge_enabled')` | `lib/features/settings/settings_screen.dart` | ~_buildGeneralKnowledgeSection |
| CFG4 | Toggle "Lembrar zoom" persistido via `writeRaw('persist_zoom')` — se false, reseta zoom para 1.0 | `lib/features/settings/settings_screen.dart` | ~_buildZoomSection |
| CFG5 | Chaves de storage centralizadas em `StorageKeys`: `apiKey`, `defaultModel`, `biometricEnabled` | `lib/core/constants/storage_keys.dart` | completo |
| CFG6 | Database versão 10, nome `dart_oraculo.db` | `lib/core/config/app_config.dart` | ~databaseVersion, databaseName |
| CFG7 | Constantes RAG (defaults): `maxChunksPerQuery=10`, `chunkMaxTokens=500`, `maxHistoryMessages=10` — agora configuráveis via Settings | `lib/core/config/app_config.dart` + `lib/features/settings/settings_screen.dart` | ~_buildAdvancedSection |
| CFG8 | Toggle global "Verificar fidelidade" persistido via `writeRaw('verify_before_promote_enabled')` — default `true` | `lib/features/settings/settings_screen.dart` | ~_buildFidelitySection |
| CFG9 | Slider "Mensagens de contexto" persistido via `writeRaw('max_history_messages')` — range 5–30 | `lib/features/settings/settings_screen.dart` | ~_buildAdvancedSection |
| CFG10 | Slider "Chunks por busca" persistido via `writeRaw('max_chunks_per_query')` — range 3–20 | `lib/features/settings/settings_screen.dart` | ~_buildAdvancedSection |
| CFG11 | Slider "Tamanho do chunk" persistido via `writeRaw('chunk_max_tokens')` — range 200–1000. Afeta apenas novos documentos | `lib/features/settings/settings_screen.dart` | ~_buildAdvancedSection |

---

## 11. FEATURES DESABILITADAS / REMOVIDAS

| # | Regra | Arquivo | Observação |
|---|-------|---------|------------|
| X1 | Web search removido — comentado com `WEB_SEARCH_DISABLED` em chat_controller e chat_screen | `chat_controller.dart`, `chat_screen.dart` | "não é conceito do app" |
| X2 | Toggle de web search por coleção existe no schema (V9) mas UI está comentada | `migrations.dart` V9, `chat_screen.dart` | Coluna existe, feature off |
| X3 | `response_source='web'` nunca é gravado (`usedWebSearch` hardcoded `false`) | `chat_controller.dart` | placeholder morto |
