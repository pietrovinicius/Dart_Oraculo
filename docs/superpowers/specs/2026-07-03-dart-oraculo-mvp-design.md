# Dart Oráculo — Design Spec (Fase 1, MVP macOS)

**Data:** 2026-07-03  
**Status:** Aprovado  
**Escopo:** Fase 1 conforme seções 2 e 9 da especificação de desenvolvimento

---

## 1. Objetivo

App Flutter desktop (macOS) de RAG pessoal. O usuário carrega PDFs, o app indexa localmente via SQLite/FTS5, e conversa com Claude (Sonnet 5 ou Opus 4.8) sobre o conteúdo carregado. Sem backend, sem sincronização, sem embeddings.

## 2. Escopo da Entrega

### Incluído
- Upload de PDF via file_picker
- Extração de texto nativo do PDF (syncfusion_flutter_pdf)
- Normalização para markdown e fragmentação em chunks
- Persistência em SQLite com FTS5 para busca de texto completo
- Chat com streaming via chamada HTTP direta a `api.anthropic.com/v1/messages`
- Seleção de modelo (Sonnet 5 / Opus 4.8) por conversa
- Histórico de conversas persistido localmente
- Faixa de citação em cada resposta (documentos e trechos consultados)
- Armazenamento seguro da chave de API (flutter_secure_storage / Keychain)
- Autenticação local via biometria ou senha do macOS (local_auth)
- Tela de configurações: chave API, modelo padrão, toggle biometria

### Excluído (conforme seção 3 da spec)
- Backend próprio
- Busca semântica / embeddings
- OCR de PDF escaneado
- Grafo visual de notas
- Sincronização entre dispositivos
- Android / iOS (Fase 2)

## 3. Arquitetura

Binário único Flutter com 5 camadas:

```
UI → Geração → Recuperação → Ingestão → Persistência + Segurança
```

- **UI:** 3 telas (bloqueio, principal, configurações)
- **Geração:** Cliente HTTP direto, streaming SSE, montagem de prompt com contexto recuperado + histórico
- **Recuperação:** Query FTS5 pelos termos da pergunta → top-N chunks por BM25
- **Ingestão:** PDF → texto por página → markdown → chunks por parágrafo/limite de tokens
- **Persistência:** SQLite via sqflite + sqflite_common_ffi, schema com triggers FTS5
- **Segurança:** flutter_secure_storage (Keychain macOS), local_auth para biometria

## 4. Modelo de Dados

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
  chunks_used TEXT,
  created_at TEXT NOT NULL
);
```

Triggers para manter `chunks_fts` sincronizado com `chunks`.

## 5. Stack Técnica

| Necessidade | Pacote |
|---|---|
| Persistência | sqflite + sqflite_common_ffi |
| Busca texto completo | FTS5 nativo SQLite |
| Extração PDF | syncfusion_flutter_pdf |
| Segurança da chave | flutter_secure_storage |
| Auth local | local_auth |
| HTTP (API Anthropic) | http (chamada direta) |
| Seleção de arquivo | file_picker |
| Markdown no chat | flutter_markdown |

## 6. Telas

### 6.1 Tela de Bloqueio
- Fundo escuro, nome do app em display serifada laranja
- Ícone de biometria centralizado
- Autenticação via local_auth (Face ID / Touch ID / senha macOS)
- Sem login remoto, sem conta de usuário

### 6.2 Tela Principal
- Sidebar retrátil à esquerda: lista de conversas + biblioteca de documentos
- Painel central: chat com bolhas user/assistant
- Cada resposta do assistant tem faixa de citação inferior mostrando documento(s) e trecho(s) consultados
- Input na base com seletor de modelo inline

### 6.3 Tela de Configurações
- Campo de chave de API (mascarado, armazenado via flutter_secure_storage)
- Seleção de modelo padrão (radio: Sonnet 5 / Opus 4.8)
- Toggle para exigir biometria ao abrir o app

## 7. Fluxos

### Ingestão
file_picker → syncfusion extrai texto por página → normaliza markdown → chunking por parágrafo (max ~500 tokens) → INSERT em documents + chunks → trigger atualiza chunks_fts

### Pergunta e Resposta
Input do usuário → query FTS5 (termos extraídos) → top-N chunks por ranking BM25 → monta prompt (system + contexto + histórico recente + pergunta) → POST api.anthropic.com/v1/messages com stream:true → renderiza resposta incrementalmente → persiste em messages com chunks_used

### Gestão de Custo de Contexto
Resumo compacto da conversa sempre presente (hot cache) + chunks completos sob demanda via FTS5. Não reenvia corpus inteiro.

## 8. Design Visual

- Paleta escura com acento laranja (conforme design.md seção 3)
- Tipografia: display serifada, corpo sans geométrica, técnica monoespaçada
- Anti-template: interface memorável, não genérica

## 9. Estratégia de Testes

- TDD obrigatório: RED → GREEN → REFACTOR
- Unit tests para cada service (PDF, chunking, FTS, Anthropic, auth, storage)
- Widget tests para cada tela
- Integration test para fluxo RAG completo (ingestão → busca → resposta)
- Coverage target: 80%+

## 10. Ordem de Implementação

1. Sprint 0: Scaffolding (pubspec, tema, config, shell rodando)
2. Sprint 1: Persistência + Segurança + Auth
3. Sprint 2: Ingestão de Documentos
4. Sprint 3: Busca FTS5
5. Sprint 4: Chat + API Anthropic
6. Sprint 5: UI Principal
7. Sprint 6: Configurações
8. Sprint 7: Integração e Polish

## 11. State Management

Sem package externo na v1. Controllers com ChangeNotifier para lógica de feature, StatefulWidget + setState para estado efêmero de UI. Riverpod entra se a complexidade justificar.

## 12. Critério de Pronto (conforme seção 9 da spec)

Usuário carrega 3+ PDFs de assuntos diferentes e obtém respostas corretas e rastreáveis à fonte.
