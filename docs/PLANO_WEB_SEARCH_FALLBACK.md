# Plano de Implementação — Web Search Fallback via Brave Search

**Data:** 2026-07-08  
**Versão alvo:** v0.22.0  
**Escopo:** Quando Claude não encontra no RAG, busca na internet e retorna com fontes

---

## Visão Geral

Quando FTS5 retorna 0 chunks relevantes E o motor é Claude (Sonnet/Opus), busca na internet via Brave Search API, injeta resultados no prompt como contexto web, e instrui o modelo a citar fontes com URLs.

**Restrição:** Só funciona com motores Claude (Anthropic). Qwen local não aciona web search.

---

## Arquitetura

```
[askQuestion] → FTS5 → 0 chunks?
    ↓ SIM (e motor é Claude)
[WebSearchService.search(query)] → Brave Search API
    ↓
Resultados (title, snippet, url) injetados no prompt como CONTEXTO WEB
    ↓
Claude responde com citação de URLs
    ↓
Resposta marcada como "fonte: internet" (não RAG)
```

---

## Novo Pacote

Nenhum — usa `http` já existente para chamar Brave Search API.

---

## Configuração

- **Brave Search API key** — armazenada no SecureStorage (como a Anthropic key)
- **Toggle por coleção** — `web_search_fallback INTEGER NOT NULL DEFAULT 0` em collections
  - 0 = desligado (default)
  - 1 = automático (busca sem perguntar)

---

## Task 1 — Migration v9 + Setting

**Arquivos:**
- `migrations.dart` → `addWebSearchFallbackToCollections`, upgradeV8toV9, allV9
- `database_helper.dart` → onCreate allV9, onUpgrade <9
- `app_config.dart` → version 9
- `settings_screen.dart` → campo para Brave Search API key

**SQL:**
```sql
ALTER TABLE collections ADD COLUMN web_search_fallback INTEGER NOT NULL DEFAULT 0;
```

---

## Task 2 — WebSearchService

**Arquivo novo:** `lib/core/services/web_search_service.dart`

```dart
class WebSearchResult {
  const WebSearchResult({required this.title, required this.url, required this.snippet});
  final String title;
  final String url;
  final String snippet;
}

class WebSearchService {
  WebSearchService({required String apiKey, http.Client? httpClient});

  /// Busca no Brave Search. Retorna até 5 resultados.
  Future<List<WebSearchResult>> search(String query, {int count = 5}) async {
    // GET https://api.search.brave.com/res/v1/web/search?q=query&count=5
    // Headers: X-Subscription-Token: apiKey
    // Parse JSON → web.results[].title, url, description
  }
}
```

---

## Task 3 — Integrar no ChatController

**Arquivo:** `lib/features/chat/chat_controller.dart` → `askQuestion()`

**Lógica (após FTS5 retornar 0 chunks):**
```dart
if (ftsResults.isEmpty && _isClaudeMotor() && webSearchEnabled) {
  final braveKey = await _storageService.readRaw('brave_api_key');
  if (braveKey != null && braveKey.isNotEmpty) {
    final webResults = await WebSearchService(apiKey: braveKey).search(question);
    // Injeta no prompt como CONTEXTO WEB
  }
}
```

**Formato no prompt:**
```
--- CONTEXTO WEB (pesquisa na internet) ---
[1] Título - url
Snippet...

[2] Título - url
Snippet...
--- FIM CONTEXTO WEB ---
```

**Instrução adicional no system prompt:**
```
7. Se usar informação do CONTEXTO WEB, cite a URL fonte entre parênteses.
```

---

## Task 4 — Indicador visual na resposta

**Arquivo:** `lib/features/chat/widgets/message_bubble.dart` ou `citation_strip.dart`

- Quando resposta usa web search, mostrar badge "🌐 Fonte: internet" em vez de "Fontes consultadas"
- Ou adicionar chips com URLs clicáveis

**Persistência:** Salvar `source_type = 'web_search'` ou flag na mensagem para saber que veio da web.

---

## Task 5 — Toggle por coleção

**Arquivo:** Sidebar ou dialog de coleção

- Menu de contexto da coleção → "Configurar" → toggle "Buscar na internet quando RAG não encontrar"
- Ou no mesmo diálogo de criação de coleção

**Alternativa simples:** Toggle global em Settings (em vez de por coleção) para v1.

---

## Task 6 — Settings: campo Brave API key

**Arquivo:** `lib/features/settings/settings_screen.dart`

Abaixo da Anthropic API key:
- Seção "Busca na internet"
- TextField para Brave Search API key
- Subtítulo: "Usado quando documentos locais não contêm a resposta"
- Link: "Obter chave em brave.com/search/api"

---

## Task 7 — Testes

- `web_search_service_test.dart` — mock HTTP, parse resultados
- `chat_controller_test.dart` — fallback web quando FTS5 vazio + toggle ligado
- `migration_v9_test.dart` — coluna web_search_fallback

---

## Fluxo Completo

1. User pergunta "como funciona HAOC?" na coleção Geral
2. FTS5 busca → 0 chunks (nenhum doc sobre HAOC)
3. Verifica: motor é Claude? ✅ Toggle web_search_fallback=1? ✅ Brave key existe? ✅
4. Brave Search: "hospital alemão oswaldo cruz HAOC" → 5 resultados
5. Injeta snippets como CONTEXTO WEB no prompt
6. Claude responde com informações + cita URLs
7. UI mostra "🌐 Fonte: internet" + links clicáveis

---

## Segurança

- Brave API key no Keychain (mesmo padrão da Anthropic key)
- Não envia conteúdo dos docs para o Brave — só a query do user
- Toggle desligado por default (opt-in)

---

## Limites

- Brave Search free: 2000 queries/mês
- Max 5 resultados por query (reduz tokens)
- Timeout: 10s para busca web (não trava o chat)

---

## Verificação

- `flutter analyze` limpo
- `flutter test` passando
- Changelog fragment
- Commit
- Teste manual: pergunta sobre tema sem docs → resposta com URLs
