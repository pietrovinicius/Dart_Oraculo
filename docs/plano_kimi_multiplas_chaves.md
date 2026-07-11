# Plano: Kimi K2.6 + Múltiplas Chaves de API

**Versão alvo:** 0.31.0  
**Data:** 2026-07-10  
**Prioridade:** Média — feature nova, sem breaking change.

---

## 1. KimiService implementando GenerationService

### Arquivo novo: `lib/core/services/kimi_service.dart`

**Interface:** `GenerationService` (mesma de `AnthropicService` e `OllamaService`).

**Especificações da API Kimi (compatível OpenAI):**

| Aspecto | Valor |
|---------|-------|
| Endpoint | `https://api.moonshot.ai/v1/chat/completions` |
| Modelo | `kimi-k2.6` |
| Formato body | OpenAI-compatible (messages array, `stream: true`) |
| Streaming | SSE com `data: {"choices": [{"delta": {"content": "..."}}]}` |
| Auth | `Authorization: Bearer <api_key>` |
| Context window | 256K tokens |
| `maxContextCharsPerChunk` | **80.000** (generoso — 256K janela permite contexto largo sem truncagem agressiva) |

**Estrutura do body (formato OpenAI):**

```dart
{
  'model': 'kimi-k2.6',
  'messages': [
    {'role': 'system', 'content': systemPrompt},
    ...history,
    {'role': 'user', 'content': question},
  ],
  'stream': true,
  'max_tokens': 4096,
}
```

**Parsing do stream (OpenAI SSE):**

```
data: {"id":"...","choices":[{"delta":{"content":"token"}}]}
data: [DONE]
```

**Exceção:** `KimiException(message, statusCode)` — padrão igual ao `AnthropicException`.

**Não reutilizar** código interno de `AnthropicService` (formato Anthropic ≠ OpenAI). Compartilha apenas a interface `GenerationService`.

---

## 2. Aviso de API Externa

### Lógica

Ao selecionar Kimi pela primeira vez na sessão, exibir AlertDialog:

> "⚠️ A Kimi é uma API externa (Moonshot AI). Não há garantia de que seus dados não serão usados para treinamento ou estudos pela provedora."

- Checkbox "Não mostrar novamente" → persiste no Keychain (`kimi_warning_dismissed`).
- Se já dismissed → não exibe.
- Botão "Entendi, continuar" → prossegue com Kimi.
- Botão "Cancelar" → volta ao modelo anterior.

**Sem bloqueio por coleção.** Kimi disponível em todas as coleções.

---

## 3. Seletor de modelo

### Arquivo modificado: `lib/features/chat/widgets/chat_input.dart`

**Mudança:** Adicionar `Kimi K2.6` ao `PopupMenuButton` entre Opus e Qwen.

**Ordem no seletor:**
1. Sonnet (padrão)
2. Opus
3. **Kimi K2.6** ← novo
4. Qwen (Local)

**Sem chave configurada:** Item aparece em cinza/disabled com tooltip "Configure a chave Kimi nas Configurações".

**Sem bloqueio por coleção** — Kimi sempre visível (se chave configurada).

### Arquivo modificado: `lib/core/config/app_config.dart`

```dart
static const String modelKimi = 'kimi-k2.6';
static const String kimiBaseUrl = 'https://api.moonshot.ai/v1/chat/completions';
```

---

## 4. Configurações de múltiplas chaves de API

### Arquivo modificado: `lib/features/settings/settings_screen.dart`

**Redesenho da seção "Chaves de API":**

Substituir o campo único por seção com 2 sub-cards:

```
┌─────────────────────────────────────────────────────┐
│  🔑 Chaves de API                                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌─── Anthropic (Claude) ────────────────────────┐  │
│  │ sk-ant-api03...••••••••...xk4z               │  │
│  │ [👁] [Salvar]                    ✅ Configurada │  │
│  └───────────────────────────────────────────────┘  │
│                                                      │
│  ┌─── Moonshot (Kimi) ──────────────────────────┐  │
│  │ Campo vazio — cole sua chave aqui            │  │
│  │ [👁] [Salvar]                    ⚠️ Ausente   │  │
│  └───────────────────────────────────────────────┘  │
│                                                      │
│  ℹ️ A chave Kimi é opcional. Sem ela, o motor Kimi  │
│     não aparece no seletor de modelo.                │
└─────────────────────────────────────────────────────┘
```

**Design:**
- Card escuro com borda laranja (como os cards existentes).
- Indicador verde "✅ Configurada" ou amarelo "⚠️ Ausente".
- Cada chave com seu botão toggle visibilidade + botão salvar.
- Tipografia e paleta conforme `design/design.md`.
- Chave Kimi armazenada no Keychain via `SecureStorageService` com key `kimi_api_key`.

### Arquivo modificado: `lib/core/constants/storage_keys.dart`

```dart
static const String kimiApiKey = 'kimi_api_key';
```

---

## 5. Integração no ChatController + ChatScreen

### Arquivo modificado: `lib/features/chat/chat_controller.dart`

```dart
// Em _updateGenerationService():
case AppConfig.modelKimi:
  final kimiKey = await SecureStorageService().getKimiApiKey();
  if (kimiKey == null || kimiKey.isEmpty) {
    throw Exception('Chave Kimi não configurada.');
  }
  activeGenerationService = KimiService(apiKey: kimiKey);
```

### Arquivo modificado: `lib/features/chat/chat_screen.dart`

- Ao selecionar Kimi: verificar chave + exibir aviso de API externa (primeira vez).
- Se chave ausente → toast "Configure a chave Kimi nas Configurações."
- Sem bloqueio por coleção.

---

## 6. Testes Previstos

### Unit: `test/unit/services/kimi_service_test.dart`

| # | Teste | Descrição |
|---|-------|----------|
| 1 | Parsing streaming OpenAI SSE | `data: {"choices":[{"delta":{"content":"token"}}]}` → yield "token" |
| 2 | Parsing stream [DONE] | Encerra stream corretamente |
| 3 | Erro 401 → KimiException | Chave inválida surfaça mensagem clara |
| 4 | Erro 429 → KimiException | Rate limit surfaça mensagem |
| 5 | Sem chave → exceção antes de request | Não faz HTTP call |
| 6 | modelDisplayName correto | `== 'Kimi K2.6'` |
| 7 | maxContextCharsPerChunk | `== 80000` |

### Unit: `test/unit/features/chat/chat_controller_test.dart` (novos)

| # | Teste | Descrição |
|---|-------|----------|
| 8 | KimiService selecionado quando modelo = kimi-k2.6 | `activeGenerationService` é KimiService |
| 9 | Fallback quando chave Kimi ausente | Seleção de Kimi sem chave → erro claro |

### Widget: `test/widget/settings_screen_test.dart` (novos)

| # | Teste | Descrição |
|---|-------|----------|
| 10 | Dois cards de chave API visíveis | Anthropic + Kimi |
| 11 | Indicador "Configurada" quando chave presente | ✅ verde visível |
| 12 | Indicador "Ausente" quando chave vazia | ⚠️ amarelo visível |
| 13 | Salvar chave Kimi persiste no storage | `readRaw('kimi_api_key')` retorna valor |

### Widget: `test/widget/chat_input_test.dart` (novo)

| # | Teste | Descrição |
|---|-------|----------|
| 14 | Kimi aparece no seletor quando chave presente | 4 items no popup |
| 15 | Kimi disabled quando chave não configurada | Item cinza |

---

## 7. Migration

Nenhuma migration necessária — sem campo novo no banco. Apenas `StorageKeys.kimiApiKey` e `StorageKeys.kimiWarningDismissed` no Keychain.

---

## 8. Ordem de Execução

| Etapa | Descrição | Arquivos |
|-------|-----------|----------|
| 1 | Constantes AppConfig + StorageKeys | app_config.dart, storage_keys.dart |
| 2 | `KimiService` completo | kimi_service.dart |
| 3 | Testes KimiService | kimi_service_test.dart |
| 4 | Settings screen redesenhada (2 cards) | settings_screen.dart |
| 5 | Testes settings (2 cards, indicadores) | settings_screen_test.dart |
| 6 | Integração ChatController | chat_controller.dart |
| 7 | Aviso Kimi (1ª vez) | chat_screen.dart |
| 8 | Seletor de modelo (Kimi item) | chat_input.dart |
| 9 | Testes widget + integration | |
| 10 | Changelog + bump v0.31.0 | |

---

## 9. Decisões do Pietro (Respondidas)

1. **Coleções bloqueadas:** Nenhuma — sem bloqueio por coleção. Remover item 2 do plano (migration de `blocked_engines` e seed). Kimi disponível em todas as coleções.

2. **Texto de aviso:** Ao selecionar Kimi, exibir aviso genérico na primeira vez:
   > "⚠️ A Kimi é uma API externa (Moonshot AI). Não há garantia de que seus dados não serão usados para treinamento ou estudos pela provedora."
   - Exibir uma vez por sessão (não repetir a cada mensagem).
   - Checkbox "Não mostrar novamente" que persiste no Keychain.

3. **Pricing Kimi K2.6:** Aceito. ~$0.001/1K input tokens → ~10x mais barato que Sonnet.

---

## 10. Riscos e Mitigações

| Risco | Mitigação |
|-------|----------|
| API Kimi instável/lenta | Timeout 60s + retry 1x + fallback toast |
| Chave Kimi expira/revogada | Erro 401 surfaça mensagem clara na UI |
| Formato SSE muda | Parsing defensivo + log de payload desconhecido |
| Bloqueio por coleção confunde usuário | Tooltip explica motivo (ver pergunta 2) |
| Migration falha em bancos antigos | Seed com `WHERE name LIKE` — idempotente |
