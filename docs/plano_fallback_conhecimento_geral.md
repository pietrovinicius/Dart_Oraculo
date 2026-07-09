# Plano de Implementação — Fallback de Conhecimento Geral

**Data:** 2026-07-09  
**Versão alvo:** v0.23.0  
**Referência de formato:** docs/PLANO_IMPLEMENTACAO_UX_CHAT.md

---

## Contexto

Hoje, quando o RAG (FTS5) não encontra chunks relevantes e o web search fallback está desligado, o Oráculo responde: *"Não encontrei essa informação nos documentos indexados."* Isso é correto para coleções onde precisão documental é crítica, mas frustrante para coleções de uso geral onde o usuário preferiria uma resposta do conhecimento do modelo com aviso claro de que não veio dos documentos.

---

## Task 1 — Migration v10: coluna `general_knowledge_fallback` em collections

**Arquivo:** `lib/core/database/migrations.dart`

**Mudança:**
```dart
// --- V10: general_knowledge_fallback em collections ---
static const String addGeneralKnowledgeFallbackToCollections = '''
  ALTER TABLE collections ADD COLUMN general_knowledge_fallback INTEGER NOT NULL DEFAULT 0;
''';

static List<String> get upgradeV9toV10 => [
  addGeneralKnowledgeFallbackToCollections,
];

static List<String> get allV10 => [
  ...allV9,
  addGeneralKnowledgeFallbackToCollections,
];
```

**Ajustes:**
- `database_helper.dart`: `databaseVersion` → 10, `onCreate` usa `allV10`, `onUpgrade` inclui v9→v10.
- `app_config.dart`: `databaseVersion` → 10.

**Padrão:** `DEFAULT 0` = desligado. Comportamento estrito preservado.

---

## Task 2 — Toggle na UI por coleção

**Arquivo:** `lib/features/chat/widgets/sidebar.dart` (dialog de configurações da coleção) ou local equivalente onde `web_search_fallback` e `verify_before_promote` são configurados.

**Mudança:** Adicionar SwitchListTile:
```dart
SwitchListTile(
  title: const Text('Conhecimento geral'),
  subtitle: const Text('Responder com conhecimento do modelo quando RAG não encontrar contexto'),
  value: generalKnowledgeFallback,
  onChanged: (v) => _updateCollectionSetting('general_knowledge_fallback', v ? 1 : 0),
)
```

**Padrão:** Desligado em coleções novas. Usuário ativa deliberadamente.

**Padrão idêntico ao** `web_search_fallback` (toggle por coleção, lido no chat_controller).

---

## Task 3 — Duas variantes de system prompt

**Arquivo:** `lib/core/services/anthropic_service.dart` → `buildRequestBody()`

**Mudança:** Aceitar parâmetro `bool allowGeneralKnowledge` (default `false`).

### Variante A — Estrita (toggle OFF, comportamento atual):
```
INSTRUÇÕES:
1. Responda SOMENTE com base no CONTEXTO abaixo.
2. Se a informação não está no contexto, diga claramente:
   "Não encontrei essa informação nos documentos indexados."
3. Cite o documento fonte e página quando possível.
4. Se o contexto contém informação parcial, mencione o que encontrou e o que falta.
5. NÃO invente informação que não está no contexto.
...
```

### Variante B — Com fallback de conhecimento geral (toggle ON):
```
INSTRUÇÕES:
1. Priorize SEMPRE o CONTEXTO abaixo para responder.
2. Se encontrar a resposta no contexto, cite o documento fonte e página.
3. Se o contexto for INSUFICIENTE para responder a pergunta, você PODE
   usar seu conhecimento geral, MAS deve sinalizar claramente com este formato:

   ⚠️ **Resposta baseada em conhecimento geral do modelo**
   (Não encontrada nos documentos indexados)

   [sua resposta aqui]

4. Nunca misture informação do contexto com conhecimento geral sem
   distinguir explicitamente qual é qual.
5. Cite documento fonte quando usar o contexto.
6. Se usar informação de um DOCUMENTO DE TRABALHO, cite o nome.
7. Se usar informação do CONTEXTO WEB, cite a URL fonte.
```

**Arquivo:** `lib/core/services/ollama_service.dart`

**Mudança idêntica:** Mesmo parâmetro `allowGeneralKnowledge`, mesmas duas variantes de prompt. O modelo Qwen local tem conhecimento geral mais limitado — isso é comportamento esperado, não defeito.

**Interface `GenerationService`:** Adicionar param opcional `bool allowGeneralKnowledge = false` em `streamResponse()`. Propagado mas nunca obrigatório.

---

## Task 4 — Lógica no chat_controller

**Arquivo:** `lib/features/chat/chat_controller.dart` → `askQuestion()`

**Mudança:** Após montar contexto (pós-FTS5, pós-web search):

```dart
// Verifica toggle de conhecimento geral na coleção
bool allowGeneralKnowledge = false;
if (collectionId != null) {
  final colRows = await _db.query('collections', where: 'id = ?', whereArgs: [collectionId]);
  if (colRows.isNotEmpty) {
    allowGeneralKnowledge = (colRows.first['general_knowledge_fallback'] as int?) == 1;
  }
}
```

Passa `allowGeneralKnowledge` ao `activeGenerationService.streamResponse()`.

**Persistência:** Quando `allowGeneralKnowledge == true` E `ftsResults.isEmpty` E não houve web search:
- Persistir `chunks_used: null` (como hoje)
- Adicionar campo ou marker para identificar que a resposta é de conhecimento geral (pode ser `chunks_used = '[]'` vs `null`, ou nova coluna `source_type` em messages).

**Decisão de design:** Usar `chunks_used = '[]'` (array vazio JSON) para marcar "respondeu mas sem chunks" vs `null` que hoje significa "mensagem do user". Isso requer ajuste mínimo.

---

## Task 5 — Distinção visual (indicador de conhecimento geral)

**Arquivo:** `lib/features/chat/widgets/citation_strip.dart`

**Mudança:** Quando `chunks_used` for `'[]'` (resposta de conhecimento geral):

```dart
// Em vez da faixa laranja de citação com chips de documento:
Container(
  margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.5)),
  ),
  child: Row(
    children: [
      Icon(Icons.auto_awesome_outlined, size: 16, color: AppColors.textMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          'Resposta baseada no conhecimento geral do modelo — sem fonte nos seus documentos',
          style: AppTextStyles.techSmall.copyWith(color: AppColors.textMuted),
        ),
      ),
    ],
  ),
)
```

**Visual:** Fundo neutro (sem laranja), ícone sutil, texto muted. Claramente diferente da faixa de citação documentária.

---

## Task 6 — Trava na promoção por like

**Arquivo:** `lib/features/chat/chat_controller.dart` → `_checkAndPromote()`

**Mudança na linha 447-452:** Onde hoje está:
```dart
final chunksUsed = msgRows.first['chunks_used'] as String?;
if (chunksUsed == null || chunksUsed.isEmpty) {
  // Sem chunks → não tem o que verificar, promove direto
  await _promoteAnswer(messageId);
  return const FeedbackResult();
}
```

Substituir por:
```dart
final chunksUsed = msgRows.first['chunks_used'] as String?;
if (chunksUsed == null || chunksUsed.isEmpty || chunksUsed == '[]') {
  // Resposta sem chunks (conhecimento geral) → requer confirmação extra
  return const FeedbackResult(
    requiresConfirmation: true,
    confirmationMessage: 'Esta resposta não veio dos seus documentos. '
        'Promover mesmo assim pode inserir informação não verificada na sua base. '
        'Continuar?',
  );
}
```

**Ajuste em `FeedbackResult`:** Adicionar campos:
```dart
class FeedbackResult {
  const FeedbackResult({
    this.isUngrounded = false,
    this.ungroundedClaims,
    this.requiresConfirmation = false,
    this.confirmationMessage,
  });

  final bool isUngrounded;
  final List<String>? ungroundedClaims;
  final bool requiresConfirmation;
  final String? confirmationMessage;
}
```

**Arquivo:** `lib/features/chat/chat_screen.dart` → handler de like

Quando `result.requiresConfirmation == true`:
- Exibir AlertDialog com `result.confirmationMessage`
- Botões: [Cancelar] [Promover mesmo assim]
- Se confirmar: chamar `chatController.forcePromote(messageId)`

---

## Task 7 — Testes (TDD obrigatório: RED → GREEN → REFACTOR)

### Unit Tests

| # | Teste | Arquivo | Verifica |
|---|-------|---------|----------|
| 1 | Migration v10 fresh install | `test/unit/database/migrations_test.dart` | Coluna `general_knowledge_fallback` existe com default 0 |
| 2 | Migration v10 upgrade | `test/unit/database/migrations_test.dart` | Upgrade v9→v10 adiciona coluna sem perder dados |
| 3 | Prompt estrito quando toggle OFF | `test/unit/services/anthropic_service_test.dart` | `buildRequestBody` com `allowGeneralKnowledge: false` contém "SOMENTE" |
| 4 | Prompt permissivo quando toggle ON | `test/unit/services/anthropic_service_test.dart` | `buildRequestBody` com `allowGeneralKnowledge: true` contém "conhecimento geral" |
| 5 | Ollama prompt estrito | `test/unit/services/ollama_service_test.dart` | Variante estrita (OFF) |
| 6 | Ollama prompt permissivo | `test/unit/services/ollama_service_test.dart` | Variante permissiva (ON) |
| 7 | Chat controller lê toggle da coleção | `test/unit/features/chat/chat_controller_test.dart` | Passa `allowGeneralKnowledge=true` quando coluna = 1 |
| 8 | Chat controller ignora toggle OFF | `test/unit/features/chat/chat_controller_test.dart` | Passa `false` quando coluna = 0 ou ausente |
| 9 | Like em resposta sem chunks → requiresConfirmation | `test/unit/features/chat/chat_controller_test.dart` | Retorna `FeedbackResult(requiresConfirmation: true)` |
| 10 | Like em resposta com chunks → promove normal | `test/unit/features/chat/chat_controller_test.dart` | Não exige confirmação extra |
| 11 | forcePromote funciona após confirmação | `test/unit/features/chat/chat_controller_test.dart` | Promove mesmo com `chunks_used = '[]'` |

### Widget Tests

| # | Teste | Arquivo | Verifica |
|---|-------|---------|----------|
| 12 | Indicador visual conhecimento geral | `test/widget/citation_strip_test.dart` | Faixa neutra exibida quando chunks vazio |
| 13 | Faixa de citação normal para chunks | `test/widget/citation_strip_test.dart` | Faixa laranja quando há citações |
| 14 | Dialog de confirmação no like | `test/widget/chat_screen_test.dart` | AlertDialog aparece quando requiresConfirmation |
| 15 | Toggle visível no dialog da coleção | `test/widget/sidebar_test.dart` | SwitchListTile de conhecimento geral presente |

---

## Ordem de Execução

| # | Task | Esforço | Dependência |
|---|------|---------|-------------|
| 1 | Migration v10 | 10 min | — |
| 2 | Toggle UI na coleção | 20 min | Task 1 |
| 3 | Duas variantes de prompt | 30 min | — |
| 4 | Lógica chat_controller | 30 min | Task 1, Task 3 |
| 5 | Indicador visual | 20 min | Task 4 |
| 6 | Trava promoção like | 30 min | Task 4 |
| 7 | Testes (14 testes) | 2h | Tasks 1-6 |

**Total estimado:** ~4h

---

## Decisões de Design (revisão 2026-07-09)

| # | Decisão |
|---|---------|
| P1 | Texto e ícone ✨ aprovados |
| P2 | Texto aprovado. Botão: **"Promover"** (não "Promover mesmo assim") |
| P3 | Não bloquear coleções. Adicionar toggle em Settings por coleção para o usuário decidir |
| P4 | Coluna nova `response_source TEXT` em `messages` com valores `'rag'` \| `'general'` \| `'web'` |

---

## Verificação Final

- `flutter analyze` limpo
- `flutter test` — 14+ novos testes passando
- Changelog fragment criado
- Teste manual: toggle OFF → resposta estrita; toggle ON + RAG vazio → resposta com aviso; like em resposta geral → dialog de confirmação
