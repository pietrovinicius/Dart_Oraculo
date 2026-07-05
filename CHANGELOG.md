# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [0.20.0] - 2026-07-05

### Adicionado
- **migrations.dart**: Migration v8 — tabela `conversation_context_attachments` para documentos de trabalho por conversa.
- **chat_controller.dart**: Métodos `addContextAttachment`, `getContextAttachments`, `removeContextAttachment`.
- **chat_controller.dart**: Injeção automática de documentos de trabalho no prompt (rotulados, truncados se excedem limite do motor).
- **anthropic_service.dart**: Instrução #6 no prompt: "cite nome do DOCUMENTO DE TRABALHO quando usar informação dele".
- **chat_screen.dart**: Diálogo de destino ao soltar/selecionar .md — "Adicionar à biblioteca" ou "Usar nesta conversa".
- **chat_screen.dart**: Indicador no cabeçalho (chip "📎 N docs") com menu para remover attachments individuais.
- **chat_screen.dart**: Drop de .md agora aceito no DropTarget (antes só imagens).
- **context_attachment_test.dart**: 3 testes unitários (injeção, truncagem, ausência após remoção).
- **migration_v8_test.dart**: 2 testes (fresh install, upgrade).
- **context_attachment_chip_test.dart**: 2 testes confirmando remoção efetiva do registro no banco + múltiplos anexos coexistem.

## [0.19.0] - 2026-07-05

### Adicionado
- **chat_controller.dart**: Método `exportConversationAsMarkdown()` — gera markdown completo com cabeçalho, mensagens, modelo, fontes citadas, nota de imagem anexada.
- **chat_controller.dart**: `_buildCitationLabels()` — diferencia citações de documento original vs resposta promovida.
- **sidebar.dart**: Opção "Exportar .md" no menu de contexto de cada conversa (ícone download).
- **chat_screen.dart**: `_exportConversation()` — file picker save dialog + feedback sucesso/erro.
- **export_conversation_test.dart**: 3 testes unitários (formato, imagem, citações diferenciadas).

### Corrigido
- **secure_storage_service.dart**: Adicionado `accessibility: KeychainAccessibility.first_unlock` para evitar prompt de senha do macOS a cada acesso ao Keychain.
- **chat_screen.dart**: Guard `positions.length == 1` em `_scrollToBottom()` — evita crash "ScrollController attached to multiple scroll views".
- **chat_screen.dart**: Debounce no botão like — impede cliques múltiplos durante verificação de fidelidade. Lock por messageId.
- **chat_screen.dart**: Feedback visual imediato no like antes da verificação terminar.
- **chat_screen.dart**: Dialog de confirmação com `barrierDismissible: false`.

## [0.17.1] - 2026-07-05

### Segurança
- **secure_storage_service.dart**: REMOVIDO fallback silencioso para arquivo JSON em texto plano (.secure_store.json). Existia desde v0.8.2. Agora falha de Keychain surfaça como SecureStorageException — nunca grava fora do Keychain.

## [0.17.0] - 2026-07-05

### Corrigido
- **fts_service.dart**: Bug crítico desde v0.4.0 — `words.join(' OR ')` retornava chunks irrelevantes para qualquer query com mais de um termo. Agora usa AND implícito com priorização de termos técnicos.
- **fts_service.dart**: Stopwords pt-BR/en (50+) removidas da query FTS5.
- **fts_service.dart**: Termos com underscore (ADEP_V) preservados como phrase match exata.
- **fts_service.dart**: Termos ALLCAPS priorizados sobre palavras comuns em queries mistas.

### Adicionado
- **fts_service.dart**: Busca em cascata: AND técnicos → OR fallback → prefix match como último recurso.
- **chat_controller.dart**: Logs detalhados — base de conhecimento (docs/chunks), cada chunk com rank + preview, tamanho contexto.
- **fts_service.dart**: Log da query sanitizada + warning quando query vira vazia.
- **anthropic_service.dart**: Prompt RAG melhorado com 5 instruções claras:
  ```
  1. Responda SOMENTE com base no CONTEXTO abaixo.
  2. Se a informação não está no contexto, diga claramente:
     "Não encontrei essa informação nos documentos indexados."
  3. Cite o documento fonte e página quando possível.
  4. Se o contexto contém informação parcial, mencione o que encontrou e o que falta.
  5. NÃO invente informação que não está no contexto.
  ```
- **chat_controller.dart**: Contexto formatado com metadados por chunk (fonte, página, relevância).

### Relação com auditoria v0.13.2
- O item "chips mostrando chunk #ID em vez de filename" (ressalva §2.4) era **parcialmente sintoma** deste bug — com OR retornando chunks genéricos, as citações vinham de documentos irrelevantes. Corrigido na v0.14.0 (lookup de filename) + v0.17.0 (busca retorna chunks corretos).
- Os 3 itens com ressalva (§2.1 descrição Qwen, §2.7 model_used legado, §2.5 Shift+Enter) eram problemas independentes — não relacionados ao bug de OR na busca.
- O item reprovado (seleção cross-bubble §2.6) é limitação de UI aceita, não relacionado ao RAG.

## [0.16.0] - 2026-07-05

### Adicionado
- **speech_service.dart**: Wrapper sobre speech_to_text, injetável e mockável. Idioma via locale do sistema.
- **chat_input.dart**: Botão de microfone para ditado por voz. Resultado parcial popula campo em tempo real. Tap novamente para parar.
- **chat_input.dart**: Tratamento de permissão negada com toast de erro claro.
- **Info.plist**: NSSpeechRecognitionUsageDescription + NSMicrophoneUsageDescription.
- **entitlements**: com.apple.security.device.audio-input em Debug e Release.
- **pubspec.yaml**: +speech_to_text ^7.0.0
- **speech_service_test.dart**: 5 testes unitários (initialize, start, stop, resultado, indisponível).
- **chat_input_speech_test.dart**: 3 widget tests (escuta + popula, permissão negada, toggle).

## [0.15.0] - 2026-07-05

### Adicionado
- **image_attachment.dart**: Modelo ImageAttachment (bytes, mediaType, path)
- **image_resize_service.dart**: Redimensiona imagens para ≤1568px no lado maior antes do envio
- **clipboard_image_service.dart**: Wrapper sobre pasteboard para leitura de imagem via Cmd+V
- **chat_input.dart**: Botão 📎 para anexar imagem + Cmd+V cola imagem do clipboard + preview com ✕
- **chat_screen.dart**: Integração completa — resize, salva em AppSupport/chat_images/, texto default se vazio
- **anthropic_service.dart**: Content blocks de imagem base64 posicionados antes do texto na API
- **ollama_service.dart**: Campo `images` com base64 no body para suporte multimodal qwen3.5
- **generation_service.dart**: Param `List<ImageAttachment>?` na interface streamResponse
- **chat_controller.dart**: Param `ImageAttachment?` em askQuestion, persiste image_path
- **message.dart**: Campo `imagePath` (String?) para persistência do caminho da imagem
- **message_bubble.dart**: Renderiza miniatura da imagem acima do texto quando imagePath presente
- **migrations.dart**: Migration v5 — `ALTER TABLE messages ADD COLUMN image_path TEXT`
- **pubspec.yaml**: +image ^4.0.0, +pasteboard ^0.5.0, +uuid ^4.0.0
- **chat_screen.dart**: Drag & drop de imagem do Finder — DropTarget envolvendo painel de chat.
- **chat_screen.dart**: Overlay visual sutil (laranja transparente + ícone) durante arraste.
- **chat_screen.dart**: Validação de extensão (jpg, jpeg, png, gif, webp) — rejeita com toast.
- **pubspec.yaml**: +desktop_drop ^0.4.0
- **chat_screen_drop_test.dart**: Widget test confirmando DropTarget na árvore.
- **chat_input_image_test.dart**: Widget test cobrindo Cmd+V com imagem (anexo) e sem imagem (texto cola normal).
- **message_bubble_image_test.dart**: Widget test cobrindo miniatura presente/ausente conforme imagePath.

### Corrigido
- **chat_input.dart**: Regressão Cmd+V — CallbackShortcuts consumia evento impedindo paste de texto. Agora usa Focus(onKeyEvent) que retorna ignored, verificando clipboard em paralelo.

### Alterado
- **app_config.dart**: databaseVersion bumped de 4 para 5
- **database_helper.dart**: onCreate usa allV5, onUpgrade inclui bloco oldVersion < 5

## [0.14.0] - 2026-07-04

### Adicionado
- **lib/core/services/generation_service.dart**: propriedade `maxContextCharsPerChunk` na interface — cada motor declara seu próprio limite (Anthropic: 20000, Ollama: 4000).
- **lib/features/chat/chat_controller.dart**: truncagem de chunks grandes no prompt com nota explicativa ("conteúdo truncado, total N linhas"). Chunk armazenado e indexado permanece íntegro.
- **lib/features/documents/document_service.dart**: `_parseJsonInIsolate()` via `compute()` para JSON > 5MB; `_persistDocumentBatch()` em lote via `db.transaction` por batch de 1000 chunks; progresso granular 0.0→0.3→0.5→1.0.
- **AGENTS.md**: ADR-016 documenta diferença intencional de limites — cloud prioriza completude, local prioriza velocidade.
- **test/unit/features/chat/chat_controller_test.dart**: 2 novos testes (chunk grande truncado no prompt; chunk pequeno passa inteiro).
- **test/unit/features/documents/document_service_test.dart**: 2 novos testes (batch insert com 1500 rows; progresso monotonicamente crescente).

## [0.13.3] - 2026-07-04

### Corrigido
- **lib/features/chat/chat_screen.dart**: removido `SelectionArea` do ListView — conflitava com scroll, gestos de botões e input. Cada bolha é selecionável independentemente.
- **lib/features/chat/widgets/chat_input.dart**: substituído `KeyboardListener` por `CallbackShortcuts` — não intercepta mais Cmd+V/Cmd+C.
- **lib/core/services/ollama_service.dart**: timeout aumentado de 2 minutos para 10 minutos.
- **lib/features/chat/chat_screen.dart**: cronômetro sutil "Pensando... Xs" / "Pensando... Xm Ys" atualiza a cada segundo.
- **pubspec.yaml**: version bumped para 0.13.2+1 (corrige rodapé que mostrava 0.11.2).

### Adicionado
- **lib/features/auth/lock_screen.dart**: flag `SKIP_AUTH` via `--dart-define` para bypass de biometria em testes automatizados. ADR-015 em AGENTS.md.
- **docs/auditoria_v0.13.2_2026-07-04.md**: relatório completo de auditoria UX + qualidade RAG.

### Alterado
- **lib/core/config/app_config.dart**: `appVersion` → 0.13.3.

## [0.13.2] - 2026-07-04

### Corrigido
- **lib/features/chat/widgets/message_bubble.dart**: mensagens do usuário agora usam `SelectableText` em vez de `Text` — permite selecionar e copiar.
- **lib/features/chat/chat_screen.dart**: `SelectionArea` envolve o `ListView` de mensagens — permite selecionar texto entre múltiplas bolhas e copiar com Cmd+C.
- **lib/core/services/ollama_service.dart**: timeout aumentado de 2 minutos para 10 minutos.
- **lib/core/config/app_config.dart**: `appVersion` corrigido para `0.13.2`.

### Adicionado
- **lib/features/chat/chat_screen.dart**: cronômetro sutil no indicador "Pensando..." — exibe tempo real, atualiza a cada segundo, para quando o primeiro token chega.

## [0.13.1] - 2026-07-04

### Corrigido
- **lib/features/documents/document_service.dart**: `_generateDescription()` agora usa `GenerationService` via injeção (pode ser Anthropic ou Ollama).
- **lib/features/chat/chat_controller.dart**: campo `model_used` na mensagem persistida agora grava `modelDisplayName` do `GenerationService` ativo.

### Refatorado
- **lib/features/chat/chat_controller.dart**: arquitetura de injeção pura. `activeGenerationService` é `late`-init com default `_anthropicService`, nunca null. Sem condicional.
- **lib/features/documents/document_service.dart**: removido `_defaultModel` — agora resolve motor via `_generationService ?? _anthropicService`.

### Adicionado
- **test/unit/services/ollama_service_test.dart**: testes complementares de model_used e geração de descrição com Qwen.

## [0.13.0] - 2026-07-04

### Adicionado
- **lib/core/services/generation_service.dart**: interface abstrata `GenerationService` com `streamResponse()` e `modelDisplayName`.
- **lib/core/services/ollama_service.dart**: motor local via Ollama (http://localhost:11434/api/chat). Modelo `qwen3.5:latest`. Rejeita modelos `:cloud`.
- **lib/core/services/anthropic_service.dart**: agora implementa `GenerationService`.
- **lib/features/chat/chat_controller.dart**: campo `activeGenerationService` para trocar motor de geração.
- **lib/features/chat/chat_screen.dart**: seletor de modelo com 3 opções (Sonnet, Opus, Qwen Local).
- **lib/features/settings/settings_screen.dart**: opção "Qwen (Local) — Offline via Ollama, sem custo de API".
- **lib/core/config/app_config.dart**: `modelQwen`, `ollamaBaseUrl`, `ollamaModel`.
- **test/unit/services/ollama_service_test.dart**: 5 testes (rejeição :cloud, aceita modelo válido, erro serviço, erro modelo, parsing streaming).

## [0.12.0] - 2026-07-04

### Adicionado
- **lib/core/services/structured_data_chunker.dart**: chunker para dados estruturados. Agrupa linhas por valor de coluna configurável, produz chunk por grupo em tabela markdown.
- **lib/features/documents/document_service.dart**: `ingestStructuredData(bytes, filename, groupByColumn)` — detecta .csv ou .json, parseia, chama structured_data_chunker.
- **lib/features/chat/chat_screen.dart**: file_picker aceita `.csv` e `.json`. Dialog para selecionar coluna de agrupamento.
- **pubspec.yaml**: dependência `csv: ^6.0.0`.
- **test/unit/services/structured_data_chunker_test.dart**: 7 testes.
- **test/unit/features/documents/document_service_test.dart**: 3 novos testes (CSV agrupado, JSON agrupado, FTS5 indexado).

## [0.11.1] - 2026-07-04

### Corrigido
- **lib/features/documents/document_service.dart**: `_generateDescription()` agora usa modelo selecionado pelo usuário nas configurações.
- **lib/features/documents/document_service.dart**: `exportAsMarkdown()` verifica se arquivo já existe antes de reprocessar (cache por identidade).

### Adicionado
- **lib/features/chat/widgets/sidebar.dart**: rodapé fixo com versão do app (via `package_info_plus`) e "Dev @PLima".
- **lib/core/config/app_config.dart**: campo `appVersion` como fallback estático.
- **pubspec.yaml**: dependência `package_info_plus: ^8.0.0`.
- **test/unit/features/documents/document_service_test.dart**: 3 novos testes (modelo Sonnet, modelo Opus, cache hit export).
- **test/widget/chat_screen_test.dart**: 1 novo teste (rodapé exibe versão e "Dev @PLima").

## [0.11.0] - 2026-07-04

### Adicionado
- **lib/core/database/migrations.dart**: coluna `description` (TEXT, nullable) em documents. Migration v3→v4.
- **lib/features/documents/document_service.dart**: `_generateDescription()` e `exportAsMarkdown(documentId)`.
- **lib/features/documents/library_screen.dart**: tela de biblioteca — cards com filename, tipo, data/hora, descrição AI, botão "Extrair .md".
- **lib/features/chat/widgets/sidebar.dart**: tap em "Documentos (N)" navega à LibraryScreen.
- **lib/features/documents/models/document.dart**: campo `description`.
- **test/unit/database/migrations_test.dart**: 2 novos testes v4.
- **test/unit/features/documents/document_service_test.dart**: 2 novos testes exportAsMarkdown.

### Alterado
- **lib/core/config/app_config.dart**: `databaseVersion` → 4.
- **lib/core/database/database_helper.dart**: `onCreate` usa `allV4`; `onUpgrade` inclui v3→v4.
- **lib/features/chat/chat_screen.dart**: passa `AnthropicService` ao `DocumentService`.

## [0.10.0] - 2026-07-04

### Adicionado
- **lib/core/database/migrations.dart**: tabela `collections` (id, name, instructions, created_at). Colunas `collection_id` em `documents` e `conversations` como FK. Migration v2→v3 com backfill automático.
- **lib/features/chat/chat_controller.dart**: `askQuestion` aceita `collectionId` e `collectionInstructions`. `createConversation` aceita `collectionId`.
- **lib/features/collections/collection_service.dart**: CRUD de coleções — list, create, getDefault, getCollection, delete (protege "Geral").
- **lib/features/collections/models/collection.dart**: modelo Collection.
- **lib/features/chat/widgets/sidebar.dart**: seletor de coleção (DropdownButton), botão "+ Coleção" com dialog.
- **lib/features/chat/chat_screen.dart**: filtra conversas e documentos por coleção ativa.
- **test/unit/features/collections/collection_service_test.dart**: 8 testes.
- **test/unit/features/chat/chat_controller_test.dart**: 3 novos testes (filtra por coleção, instrução injetada, conversas isoladas).
- **test/unit/database/migrations_test.dart**: 4 novos testes v3.

### Alterado
- **lib/core/config/app_config.dart**: `databaseVersion` → 3.

## [0.9.1] - 2026-07-03

### Corrigido
- **lib/core/database/migrations.dart**: adicionado `ALTER TABLE conversations ADD COLUMN pinned` no upgradeV1toV2. Bancos criados na v1 original causavam erro "no such column: pinned".
- **lib/features/settings/settings_screen.dart**: chave de API exibida mascarada (primeiros 10 + •••••••• + últimos 4). Impede salvar versão mascarada.
- **test/unit/database/migrations_test.dart**: teste de upgrade usa schema v1 original (sem pinned).

## [0.9.0] - 2026-07-03

### Adicionado
- **lib/features/chat/chat_screen.dart**: upload múltiplo (allowMultiple=true) com validação de máximo 10 arquivos. Barra de progresso determinada + label "Processando X de Y". Resumo de lote ao final.
- **lib/features/chat/widgets/message_bubble.dart**: botões de like/dislike em respostas do assistant, mutuamente exclusivos com toggle.
- **lib/core/database/migrations.dart**: tabela `message_feedback` (id, message_id FK, value CHECK 'like'/'dislike', created_at).
- **lib/features/chat/chat_controller.dart**: `setFeedback(messageId, value)` e `getFeedback(messageId)`.
- **lib/core/services/pdf_service.dart**: callback opcional `onProgress(double)` propagado durante extração por página.
- **lib/features/documents/document_service.dart**: `onProgress` propagado de pdf_service e markdown.
- **test/unit/database/migrations_test.dart**: 5 novos testes v2.
- **test/unit/features/chat/chat_controller_test.dart**: 6 novos testes de feedback.

### Alterado
- **lib/core/config/app_config.dart**: `databaseVersion` → 2.
- **database_helper.dart**: `onCreate` usa `allV2`.

## [0.8.2] - 2026-07-03

### Corrigido
- **lib/core/services/secure_storage_service.dart**: erro -34018 do Keychain corrigido com `MacOsOptions(useDataProtectionKeyChain: false)`. Fallback automático para arquivo JSON local.
- **lib/features/settings/settings_screen.dart**: botão salvar API key valida chave vazia e envolve em try/catch.
- **macos/Runner/DebugProfile.entitlements**: sandbox desabilitado para debug + `network.client`.
- **macos/Runner/Release.entitlements**: adicionado `network.client`.

### Adicionado
- **lib/core/services/logger_service.dart**: logger centralizado com output em console e arquivo log.txt.
- Logging em todos os fluxos: SecureStorage, AuthService, SettingsController, DocumentService, ChatController.
- **Anotacoes.txt**: instruções de setup macOS e Windows.
- **run_macos.sh**: script de execução para macOS.
- **run_windows.bat**: script de execução para Windows.

## [0.8.0] - 2026-07-03

### Adicionado
- **lib/core/services/markdown_normalizer.dart**: normalização de texto bruto de PDF para markdown estruturado. Heurísticas calibradas com Oracle.pdf real.
- **lib/features/documents/document_service.dart (ingestMarkdown)**: ingestão direta de arquivos .md.
- **test/unit/services/markdown_normalizer_test.dart**: 9 testes cobrindo todos os padrões heurísticos.
- **test/unit/features/documents/document_service_test.dart**: 3 novos testes para ingestão de markdown.
- **AGENTS.md**: ADR-012 (conformidade Syncfusion), ADR-013 (normalização PDF→markdown), ADR-014 (markdown como formato de entrada).
- **test/integration/rag_flow_test.dart**: 3 testes end-to-end cobrindo fluxo RAG completo.

### Alterado
- **lib/features/documents/document_service.dart**: pipeline de PDF agora normaliza para markdown antes do chunking.
- **lib/features/chat/chat_screen.dart**: file_picker aceita extensões .pdf e .md.

### Verificado
- 83 testes passando (unit + widget + integration).
- `flutter analyze` sem issues.
- `flutter build macos --debug` compilando com sucesso.
- Critério de pronto da Fase 1 atendido: fluxo ingestão → busca → resposta rastreável à fonte funcional.

## [0.7.0] - 2026-07-03

### Adicionado
- **lib/features/settings/settings_controller.dart**: controller com load, saveApiKey, saveModel, saveBiometric, deleteApiKey.
- **lib/features/settings/settings_screen.dart**: tela completa — campo de API key mascarado, seleção de modelo, switch biometria.
- **test/widget/settings_screen_test.dart**: 7 testes unitários do SettingsController.

## [0.6.0] - 2026-07-03

### Adicionado
- **lib/features/chat/chat_screen.dart**: tela principal completa — sidebar retrátil, painel de chat, toolbar com seletor de modelo, importação de PDF, estado vazio.
- **lib/features/chat/widgets/message_bubble.dart**: bolha de mensagem estilizada com alinhamento por role.
- **lib/features/chat/widgets/citation_strip.dart**: faixa de citação com chips de documento e página.
- **lib/features/chat/widgets/chat_input.dart**: campo de texto com envio por Enter.
- **lib/features/chat/widgets/sidebar.dart**: lista de conversas com seleção, delete, botão nova conversa.
- **test/widget/chat_screen_test.dart**: 8 widget tests.

## [0.5.0] - 2026-07-03

### Adicionado
- **lib/core/services/anthropic_service.dart**: cliente HTTP direto para api.anthropic.com/v1/messages com streaming SSE.
- **lib/features/chat/chat_controller.dart**: controller principal do chat — orquestra pergunta → FTS5 → contexto → API streaming → persistência.
- **lib/features/chat/models/conversation.dart**: modelo Conversation.
- **lib/features/chat/models/message.dart**: modelo Message com chunksUsed.
- **test/unit/services/anthropic_service_test.dart**: 9 testes.
- **test/unit/features/chat/chat_controller_test.dart**: 6 testes.

## [0.4.0] - 2026-07-03

### Adicionado
- **lib/core/services/fts_service.dart**: busca de texto completo via FTS5 com ranking BM25.
- **test/unit/services/fts_service_test.dart**: 8 testes.

## [0.3.0] - 2026-07-03

### Adicionado
- **lib/core/services/pdf_service.dart**: extração de texto nativo de PDF por página usando syncfusion_flutter_pdf.
- **lib/core/services/chunking_service.dart**: fragmentação de texto em chunks por parágrafo com limite configurável de tokens.
- **lib/features/documents/document_service.dart**: orquestra fluxo completo de ingestão.
- **lib/features/documents/models/document.dart**: modelo Document.
- **lib/features/documents/models/chunk.dart**: modelo Chunk.
- **test/unit/services/pdf_service_test.dart**: 4 testes.
- **test/unit/services/chunking_service_test.dart**: 6 testes.
- **test/unit/features/documents/document_service_test.dart**: 6 testes.

## [0.2.0] - 2026-07-03

### Adicionado
- **lib/core/services/secure_storage_service.dart**: wrapper sobre flutter_secure_storage.
- **lib/features/auth/auth_service.dart**: serviço de autenticação local via local_auth.
- **lib/features/auth/lock_screen.dart**: tela de bloqueio funcional.
- **test/unit/database/migrations_test.dart**: 9 testes.
- **test/unit/services/secure_storage_service_test.dart**: 9 testes.
- **test/unit/features/auth/auth_service_test.dart**: 7 testes.

### Alterado
- **test/unit/app_smoke_test.dart**: corrigido ordenação de imports.

## [0.1.0] - 2026-07-03

### Adicionado
- **pubspec.yaml**: dependências completas da Fase 1.
- **analysis_options.yaml**: lint rules rigorosas.
- **.gitignore**: atualizado para Flutter + macOS + IDE + coverage.
- **lib/core/theme/**: paleta escura com acento laranja, tipografia 3 famílias, ThemeData unificado.
- **lib/core/config/**: rotas nomeadas, constantes globais e config da API Anthropic.
- **lib/core/constants/storage_keys.dart**: chaves para flutter_secure_storage.
- **lib/core/database/migrations.dart**: schema SQLite completo com triggers de sincronização FTS5.
- **lib/core/database/database_helper.dart**: singleton SQLite via sqflite_common_ffi.
- **lib/main.dart**: entry point com inicialização FFI.
- **lib/app.dart**: MaterialApp com tema escuro e rotas.
- **lib/features/auth/lock_screen.dart**: stub da tela de bloqueio.
- **lib/features/chat/chat_screen.dart**: stub da tela principal.
- **lib/features/settings/settings_screen.dart**: stub da tela de configurações.
- **macos/**: runner nativo macOS.
- **test/unit/app_smoke_test.dart**: teste mínimo de instanciação.
- **CLAUDE.md**: regras de execução do projeto.
- **AGENTS.md**: 11 decisões arquiteturais com justificativa.
