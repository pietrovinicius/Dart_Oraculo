# AGENTS.md — Decisões Arquiteturais

Este documento registra as decisões arquiteturais do Dart Oráculo com a justificativa de cada uma. Separado do CLAUDE.md (regras de execução) por design.

---

## ADR-001: SQLite com sqflite + sqflite_common_ffi (não Drift)

**Decisão:** Usar sqflite + sqflite_common_ffi com SQL raw para persistência.

**Razão:** O schema é simples (5 tabelas) e estável. Drift adicionaria uma camada de code generation e uma dependência de aprendizado sem ganho proporcional para um app pessoal. SQL raw dá controle total sobre FTS5, triggers e queries de ranking BM25 sem abstrações intermediárias.

**Revisitar quando:** O schema crescer além de 10 tabelas ou migrations ficarem difíceis de manter manualmente.

---

## ADR-002: Busca lexical FTS5, sem embeddings

**Decisão:** Busca de texto completo via tabela virtual FTS5 nativa do SQLite com ranking BM25.

**Razão:** Anthropic não oferece endpoint de embeddings próprio. Usar Voyage AI exigiria segunda chave de API e serviço externo, contrariando a premissa de zero-backend. Busca lexical é suficiente para o volume esperado da v1 (dezenas de PDFs, não milhares). FTS5 é zero-dependência extra — já está no SQLite.

**Revisitar quando:** Dados reais de uso mostrarem que busca lexical retorna resultados insatisfatórios (Fase 4 do roadmap).

---

## ADR-003: Cliente HTTP direto, sem LangChain.dart

**Decisão:** Chamada direta a `api.anthropic.com/v1/messages` via pacote `http`.

**Razão:** O app faz uma única operação: montar prompt com contexto e chamar a API. Não há encadeamento de prompts, agentes, nem tools na v1. LangChain.dart (`langchain_anthropic`) adicionaria uma dependência de terceiro cuja atualização não controlamos, para uma abstração que não economiza código neste cenário.

**Revisitar quando:** Lógica de encadeamento de prompts crescer (multi-step reasoning, tool use, agentic flows).

---

## ADR-004: Sem state management package na v1

**Decisão:** ChangeNotifier para controllers de feature, setState para estado efêmero de UI. Sem Riverpod, BLoC ou Provider.

**Razão:** App pessoal com 3 telas e fluxos lineares. Overhead de setup, boilerplate e dependency injection de um package não se justifica. Controllers são testáveis com ChangeNotifier + listeners em testes unitários.

**Revisitar quando:** Número de providers ultrapassar 8-10, ou surgir necessidade de scoped state complexo (ex: multi-tab com estado independente).

---

## ADR-005: Estrutura por feature, não por tipo

**Decisão:** Organizar `lib/` em `features/auth`, `features/chat`, `features/documents`, `features/settings`, com modelos dentro de cada feature.

**Razão:** Coesão alta — tudo relacionado a "chat" está junto (tela, controller, widgets, modelos). Evita pasta `models/` genérica com 20 arquivos desconexos. Facilita navegação e refatoração por domínio.

---

## ADR-006: Segurança da chave via Keychain (flutter_secure_storage)

**Decisão:** Chave de API armazenada exclusivamente via flutter_secure_storage, que usa Keychain no macOS.

**Razão:** A chave nunca deve existir em texto plano no disco, em SharedPreferences, nem em memória além do necessário. Keychain é o mecanismo nativo do macOS para credenciais, com proteção por hardware quando disponível.

---

## ADR-007: Autenticação local sem conta de usuário

**Decisão:** local_auth para Face ID / Touch ID / senha do macOS. Sem login remoto, sem servidor de autenticação.

**Razão:** Função de privacidade no dispositivo, não de identidade. O app é pessoal, single-user, offline-first. Biometria protege contra acesso físico não autorizado ao conteúdo indexado.

---

## ADR-008: Chunking por parágrafo com limite de tokens

**Decisão:** Fragmentar texto extraído por parágrafo, com limite superior de ~500 tokens por chunk. Parágrafos que excedem o limite são subdivididos por sentença.

**Razão:** Parágrafos preservam coerência semântica natural do texto. O limite de tokens garante que múltiplos chunks cabem no contexto do prompt sem estourar a janela. 500 tokens é conservador o suficiente para permitir 10-15 chunks no prompt com margem para histórico.

---

## ADR-009: Streaming de resposta via SSE

**Decisão:** Usar `stream: true` na chamada à API Anthropic e renderizar tokens incrementalmente na UI.

**Razão:** UX de chat exige feedback imediato. Esperar resposta completa antes de renderizar gera percepção de lentidão inaceitável, especialmente com Opus 4.8 que pode levar 10-30s para respostas longas.

---

## ADR-010: Hot cache + recuperação sob demanda

**Decisão:** Manter resumo compacto da conversa sempre no prompt (hot cache) e buscar chunks completos via FTS5 apenas para a pergunta atual.

**Razão:** Evita reenviar corpus inteiro a cada turno. Controla custo de tokens conforme o corpus cresce. Inspirado no padrão de cache do claude-obsidian.

---

## ADR-011: messages.chunks_used para rastreabilidade

**Decisão:** Coluna `chunks_used` em `messages` armazena IDs dos chunks usados para gerar cada resposta.

**Razão:** Permite a faixa de citação mostrar exatamente quais documentos e trechos foram consultados. Rastreabilidade é critério de pronto da Fase 1 — respostas devem ser "rastreáveis à fonte".

---

## ADR-012: Conformidade de licença Syncfusion

**Decisão:** O pacote `syncfusion_flutter_pdf` requer conformidade com a Community License da Syncfusion para distribuição. A partir da versão 25.x, `SyncfusionLicense.registerLicense()` foi **deprecated** — registro de chave em runtime não é mais necessário. Porém a obrigação de licenciamento (Community ou Comercial) permanece válida para distribuição.

**Razão:** A Syncfusion oferece Community License gratuita para desenvolvedores individuais e empresas com menos de USD 1M de receita e 5 desenvolvedores. O uso em desenvolvimento local não requer ação. Distribuição pública exige registro prévio no programa.

**Obrigações antes de distribuir:**
1. Registrar-se em https://www.syncfusion.com/products/communitylicense
2. Manter conformidade com os termos enquanto o pacote estiver no app

**Nota técnica:** Na versão 25.2.7 usada neste projeto, `SyncfusionLicense.registerLicense()` está deprecated com mensagem "License registration is not required now". Não há chamada de registro em `main.dart`.

**Termos completos:** https://www.syncfusion.com/content/downloads/syncfusion_license.pdf

**Revisitar quando:** Migrar para alternativa open-source (ex: `pdf_text` ou `pdfx`) se a dependência da Syncfusion se tornar problemática.

---

## ADR-013: Normalização de PDF para markdown antes do chunking

**Decisão:** O texto bruto extraído do PDF é normalizado para markdown estruturado antes de ser entregue ao chunking. A normalização detecta títulos por heurística (capítulo por dígito colado a maiúscula, seções numeradas, ALL CAPS), converte linhas de sumário em listas, remove watermarks conhecidos, e marca quebras de página.

**Razão:** O texto bruto do syncfusion não preserva formatação. A normalização produz markdown que: (1) é melhor para indexação FTS5 (títulos separados do corpo), (2) melhora a qualidade do contexto enviado à API (estrutura hierárquica), e (3) é o que fica armazenado e indexado, conforme seção 7 da especificação.

**Heurísticas calibradas para:** Material didático/técnico (apostilas, papers, manuais). PDFs com layout de duas colunas ou slides exportados podem ter resultados inferiores.

---

## ADR-014: Ingestão de markdown como formato de entrada direto

**Decisão:** O pipeline de ingestão aceita arquivos `.md` além de `.pdf`. Para markdown, o conteúdo já está no formato final e vai direto para o chunking, sem passar pelo pdf_service nem pelo normalizer.

**Razão:** A especificação sempre previu PDF e markdown como formatos de entrada. Markdown é o formato nativo de notas pessoais (Obsidian, Logseq, etc.), e o público-alvo do app provavelmente já tem uma base de conhecimento em markdown. Chunks de markdown recebem `page: null` no schema, já que o arquivo não tem conceito de página.

---

## ADR-015: Flag SKIP_AUTH para bypass de autenticação em debug

**Decisão:** A flag `--dart-define=SKIP_AUTH=true` permite pular a tela de bloqueio biométrico em builds de debug. Valor padrão: `false`. Nunca deve ser habilitada em builds de Release.

**Razão:** Testes automatizados e auditorias end-to-end não conseguem interagir com biometria (Touch ID/Face ID). O bypass permite exercitar o fluxo completo sem intervenção manual.

**Risco de segurança:** Se acidentalmente habilitada em produção, qualquer pessoa com acesso físico ao dispositivo entra no app sem autenticação. Mitigações:
1. Flag é `const` compilada — não existe em builds que não passam `--dart-define`
2. Valor padrão é `false` — omitir a flag = auth normal
3. Documentada aqui como risco controlado para auditoria
4. Nunca deve aparecer em scripts de build de Release

**Revisitar quando:** Testes automatizados com mock de `local_auth` permitirem bypass sem flag de compilação.

---

## ADR-016: Limite de contexto por chunk diferenciado por motor de geração

**Decisão:** Cada `GenerationService` declara `maxContextCharsPerChunk`. AnthropicService: 20000. OllamaService: 4000. O `chat_controller` lê esse valor do motor ativo ao montar o contexto.

**Razão intencional:**
- **Motores em nuvem (Anthropic, 1M tokens):** priorizam completude de resposta. Tabelas grandes como CPOE_MATERIAL (481 colunas) passam quase inteiras, ao custo de mais tokens cobrados.
- **Motor local (Ollama/Qwen 3.5, 262K tokens):** prioriza velocidade percebida. Trunca tabelas acima de ~50 colunas para manter inferência em tempo aceitável no hardware local.

**Comportamento da truncagem:** O chunk permanece íntegro no banco e no FTS5 (indexação completa). A truncagem acontece apenas no momento de montar o prompt — com nota explicativa ao modelo: "conteúdo truncado, total N linhas, consulte o documento completo."

**Revisitar quando:** Mudança de hardware local ou modelo mais rápido justifique aumentar o limite do Ollama.
