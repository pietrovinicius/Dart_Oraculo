# Especificação de Desenvolvimento — Oráculo (nome de trabalho)

Versão 0.1 · Documento vivo, atualizar a cada decisão de arquitetura relevante

## 1. Visão geral

Aplicativo pessoal de RAG (Retrieval-Augmented Generation) construído em Flutter, sem backend, rodando primeiro em macOS e depois em Android e iOS a partir da mesma base de código. O usuário carrega documentos (PDF na v1, outros formatos depois), o app indexa o conteúdo localmente, e as perguntas do usuário são respondidas via chat usando a API da Anthropic (Sonnet 5 como padrão, Opus 4.8 como opção para raciocínio mais profundo), com o contexto relevante recuperado do índice local e injetado no prompt.

Peça de portfólio. Segue os padrões já consolidados nos seus outros projetos: TDD como lei (RED → GREEN → REFACTOR), commits convencionais em português, CLAUDE.md e AGENTS.md como documentos distintos (regras de execução versus decisões arquiteturais com justificativa), feedback em três camadas para erros de usuário (toast, alerta inline, modal).

## 2. Escopo do MVP (Fase 1, macOS)

- Upload manual de arquivos PDF pelo usuário via file picker nativo.
- Extração de texto do PDF e conversão para markdown normalizado.
- Indexação do conteúdo em SQLite com busca de texto completo (FTS5).
- Tela de chat: usuário pergunta, app recupera os trechos mais relevantes do índice, monta o prompt e chama a API da Anthropic.
- Configuração da chave de API da Anthropic pelo usuário, armazenada de forma segura no dispositivo.
- Seleção de modelo (Sonnet 5 ou Opus 4.8) por conversa ou por pergunta.
- Histórico de conversas persistido localmente e reaproveitado como parte do corpus indexado.

## 3. Fora de escopo por enquanto

- Backend próprio ou qualquer serviço de terceiros além da API da Anthropic.
- Busca semântica por embeddings (Anthropic não oferece endpoint de embeddings próprio; a recomendação oficial é a Voyage AI, o que implicaria uma segunda chave de API, contrariando a restrição de custo único). Fica registrada como evolução possível na Fase 4.
- OCR de PDF escaneado (só texto nativo do PDF na v1).
- Grafo visual de notas e tags. É um objetivo real seu, mas entra como Fase 3, depois que o motor de ingestão e chat estiver estável, para não misturar dois riscos técnicos no mesmo sprint.
- Sincronização entre dispositivos. Cada instalação mantém seu próprio banco local.

## 4. Arquitetura

Camadas do app, todas dentro do mesmo binário Flutter, sem processo servidor:

**Camada de ingestão.** Recebe o arquivo, extrai texto, normaliza para markdown, fragmenta em chunks de tamanho controlado (por parágrafo ou por limite de tokens, a decidir em prototipagem) e grava no banco local com metadados de origem (arquivo, página, posição).

**Camada de persistência.** SQLite via `drift` ou `sqflite` mais `sqflite_common_ffi` para suporte a desktop. Guarda três entidades principais: documentos, chunks indexados e conversas. Uma tabela virtual FTS5 espelha o texto dos chunks para busca de texto completo com ranqueamento tipo BM25.

**Camada de recuperação.** Ao receber uma pergunta, consulta a tabela FTS5 pelos termos da pergunta, retorna os N chunks mais relevantes, e monta o contexto que vai para o prompt. Sem embeddings nem vetor de similaridade na v1.

**Camada de geração.** Cliente Dart que chama `POST https://api.anthropic.com/v1/messages` com o contexto recuperado, o histórico recente da conversa e a pergunta atual. Streaming de resposta para a UI.

**Camada de segurança.** Armazenamento da chave de API via `flutter_secure_storage`, usando Keychain no macOS e no iOS, Keystore no Android. A chave nunca trafega para nenhum destino além do domínio `api.anthropic.com`.

## 5. Stack técnica e dependências candidatas

| Necessidade | Pacote candidato | Observação |
|---|---|---|
| Persistência local (mobile + desktop) | `sqflite` + `sqflite_common_ffi`, ou `drift` | `drift` dá tipagem forte sobre SQL, vale avaliar o custo de aprendizado contra o ganho |
| Busca de texto completo | Tabela virtual FTS5 nativa do SQLite | Sem pacote extra, é recurso do próprio SQLite |
| Extração de texto de PDF | `syncfusion_flutter_pdf` ou equivalente | Cobre PDF com texto nativo; PDF escaneado fica fora de escopo da v1 |
| Armazenamento seguro da chave | `flutter_secure_storage` | Keychain, Keystore, Credential Manager conforme plataforma |
| Cliente HTTP para a API da Anthropic | `http` ou `dio`, chamada direta | Alternativa avaliada: pacote `langchain_anthropic` do LangChain.dart, que já embrulha a chamada; decisão em aberto, ver seção 11 |
| Seleção de arquivo | `file_picker` | Cobre as três plataformas alvo |
| Renderização de markdown no chat | `flutter_markdown` | Para exibir resposta formatada |

## 6. Modelo de dados (rascunho de schema)

```sql
CREATE TABLE documents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  filename TEXT NOT NULL,
  source_path TEXT,
  imported_at TEXT NOT NULL
);

CREATE TABLE chunks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  document_id INTEGER NOT NULL REFERENCES documents(id),
  page INTEGER,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE VIRTUAL TABLE chunks_fts USING fts5(
  content,
  content='chunks',
  content_rowid='id'
);

CREATE TABLE conversations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  title TEXT,
  created_at TEXT NOT NULL
);

CREATE TABLE messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  conversation_id INTEGER NOT NULL REFERENCES conversations(id),
  role TEXT NOT NULL CHECK(role IN ('user', 'assistant')),
  content TEXT NOT NULL,
  model_used TEXT,
  created_at TEXT NOT NULL
);
```

Schema sujeito a revisão assim que a prototipagem de chunking definir o tamanho ideal de fragmento.

## 7. Fluxos principais

**Ingestão de documento.** Usuário seleciona PDF → extração de texto por página → normalização para markdown → fragmentação em chunks → gravação em `documents` e `chunks` → atualização automática da tabela `chunks_fts` via trigger do SQLite.

**Pergunta e resposta.** Usuário digita pergunta → consulta FTS5 pelos termos da pergunta → seleção dos chunks mais relevantes, respeitando um teto de tokens → montagem do prompt com contexto recuperado mais histórico recente da conversa → chamada à API da Anthropic com o modelo selecionado → resposta em streaming exibida no chat → gravação da pergunta e da resposta em `messages`.

**Gestão de custo de contexto.** Conforme o corpus cresce, evitar reenviar tudo a cada pergunta. Manter um resumo compacto sempre presente no prompt (equivalente ao hot cache do claude-obsidian) e recuperar chunks completos só sob demanda via FTS5, em vez de despejar o vault inteiro a cada turno.

## 8. Segurança

Chave de API inserida manualmente pelo usuário numa tela de configurações, armazenada via `flutter_secure_storage`, nunca em `SharedPreferences` nem em arquivo plano. Como cada usuário usa a própria chave num app que ele mesmo compila ou instala para uso pessoal, o risco de chave embutida em binário distribuído para terceiros não se aplica aqui; o modelo de ameaça relevante é proteger a chave de outros processos no mesmo dispositivo, coberto pelo armazenamento seguro do sistema operacional.

## 9. Roadmap por fases

**Fase 1, MVP macOS.** Ingestão de PDF, indexação FTS5, chat funcional com Sonnet e Opus, armazenamento seguro de chave. Critério de pronto: usuário carrega três ou mais PDFs de assuntos diferentes e obtém respostas corretas e rastreáveis à fonte.

**Fase 2, portabilidade mobile.** Mesma base de código rodando em Android e iOS, com atenção a UI responsiva e ao comportamento do `sqflite_common_ffi` versus `sqflite` nativo por plataforma.

**Fase 3, camada de organização.** Extração de wikilinks e tags dos markdowns gerados, grafo visual via `graphview`, seguindo o precedente validado pelo Ozan.

**Fase 4, avaliação de busca semântica.** Só entra se a busca lexical se mostrar insuficiente na prática. Decisão entre segunda chave de API (Voyage), embeddings on-device (ONNX ou TFLite) ou manter lexical, avaliada com dados reais de uso, não antecipada por especulação.

## 10. Riscos e decisões em aberto

A Anthropic não tem endpoint de embeddings próprio, o que já está resolvido no desenho da v1 ao optar por busca lexical, mas volta a ser decisão real se a Fase 4 for acionada. A extração de texto de PDF cobre só documentos com texto nativo; PDF escaneado como imagem fica sem suporte até se decidir se OCR entra local ou via serviço externo. O crescimento do corpus ao longo do tempo pressiona o custo de token por conversa, mitigado pelo padrão de cache mais índice descrito na seção 7, mas ainda não validado com volume real de dados. Por fim, a escolha entre cliente HTTP direto contra a API da Anthropic ou o pacote `langchain_anthropic` do LangChain.dart segue em aberto: o cliente direto é mais simples de auditar e manter para um app pessoal, o pacote pronto poupa código mas adiciona uma dependência de terceiro cuja atualização você não controla. Recomendo começar com chamada direta na Fase 1 e revisitar essa escolha só se a lógica de encadeamento de prompts crescer a ponto de justificar o framework.

## 11. Referências e precedentes estudados

- `imrofayel/Ozan`, app Flutter de conhecimento pessoal inspirado no Obsidian: valida `sqflite` mais `graphview` como arquitetura local sem backend, mas usa Gemini na camada de IA, não Anthropic, e não resolve ingestão de PDF.
- `davidmigloz/langchain_dart`, porta Dart do LangChain, com pacote dedicado `langchain_anthropic` e vector stores locais (`MemoryVectorStore`, integração com ObjectBox). Framework mais pesado que o necessário para a v1, mas referência útil para a Fase 4.
- `AgriciDaniel/claude-obsidian`, skill para Claude Code que organiza markdowns em vault do Obsidian com padrão de cache quente mais índice, inspiração direta para a estratégia de gestão de custo de contexto da seção 7.
