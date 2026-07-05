# Plano de Implementação — Verificação de Fidelidade antes de Promoção

**Data:** 2026-07-05  
**Versão alvo:** v0.19.0  
**Escopo:** Checagem cruzada Sonnet↔Opus antes de promover resposta

---

## Visão Geral

Ao clicar like (motor Anthropic), verificador cruzado valida se resposta está fundamentada nos chunks.  
Se não → confirma com user antes de promover. Se sim → promove silenciosamente.

---

## Migration v7

Nova coluna em `collections`:
- `verify_before_promote INTEGER NOT NULL DEFAULT 1` (1=ligado, 0=desligado)

---

## Task 1 — Migration v7 + Teste

**Arquivos:**
- `app_config.dart` → version 7
- `migrations.dart` → upgradeV6toV7, allV7
- `database_helper.dart` → onCreate allV7, onUpgrade <7
- `test/unit/database/migration_v7_test.dart`

**SQL:**
```sql
ALTER TABLE collections ADD COLUMN verify_before_promote INTEGER NOT NULL DEFAULT 1;
```

---

## Task 2 — Toggle por coleção no Settings

**Arquivos:**
- `lib/features/settings/settings_controller.dart`
- `lib/features/settings/settings_screen.dart` (ou tela de coleção)
- Collection model

Na verdade, como é por coleção, faz mais sentido no **menu de contexto da coleção** (sidebar) ou num dialog de configuração de coleção. Vou adicionar um método no controller.

**Novo método:**
```dart
Future<void> setVerifyBeforePromote(int collectionId, bool enabled) async {
  await _db.update('collections',
    {'verify_before_promote': enabled ? 1 : 0},
    where: 'id = ?', whereArgs: [collectionId]);
}

Future<bool> isVerifyBeforePromoteEnabled(int collectionId) async {
  final rows = await _db.query('collections', where: 'id = ?', whereArgs: [collectionId]);
  if (rows.isEmpty) return true;
  return (rows.first['verify_before_promote'] as int) == 1;
}
```

---

## Task 3 — Serviço de Verificação de Fidelidade

**Arquivo novo:** `lib/core/services/fidelity_checker.dart`

```dart
class FidelityCheckResult {
  const FidelityCheckResult({required this.isGrounded, this.ungroundedClaims});
  final bool isGrounded;
  final List<String>? ungroundedClaims;
}

class FidelityChecker {
  FidelityChecker({required AnthropicService verifierService});

  Future<FidelityCheckResult> check({
    required String answerText,
    required String chunksContext,
    required String verifierModel,
  }) async { ... }
}
```

**Prompt do verificador:**
```
Você é um verificador de fidelidade. Analise se TODAS as afirmações factuais
da RESPOSTA abaixo estão sustentadas pelos TRECHOS FONTE fornecidos.

Resposta apenas em formato JSON:
{"grounded": true} se tudo fundamentado.
{"grounded": false, "claims": ["afirmação X não está nos trechos"]} se houver não fundamentadas.

--- TRECHOS FONTE ---
{chunks}
--- FIM TRECHOS ---

--- RESPOSTA A VERIFICAR ---
{answer}
--- FIM RESPOSTA ---
```

**Cache:** `cache_control: {type: "ephemeral"}` no bloco system com chunks.

---

## Task 4 — Integrar checagem no fluxo de like

**Arquivo:** `lib/features/chat/chat_controller.dart` → `_promoteAnswer()`

**Lógica:**
1. Se motor = Qwen → skip checagem, promove direto
2. Se coleção tem verify_before_promote = 0 → skip, promove direto
3. Determina verificador: Sonnet gerou → Opus verifica; Opus gerou → Sonnet verifica
4. Monta contexto dos chunks_used da mensagem
5. Chama `FidelityChecker.check()`
6. Se grounded → promove silenciosamente
7. Se !grounded → retorna resultado ao caller (chat_screen) para confirmar

**Mudança de API:**
`setFeedback` precisa retornar resultado da checagem para chat_screen decidir.

```dart
/// Resultado do feedback + checagem
class FeedbackResult {
  const FeedbackResult({this.needsConfirmation = false, this.ungroundedClaims});
  final bool needsConfirmation;
  final List<String>? ungroundedClaims;
}

Future<FeedbackResult> setFeedback(int messageId, String? value) async { ... }
```

---

## Task 5 — Dialog de confirmação no chat_screen

**Arquivo:** `lib/features/chat/chat_screen.dart` → `_onFeedbackChanged()`

Quando `setFeedback` retorna `needsConfirmation: true`:
- Mostra AlertDialog:
  - Título: "Verificação de fundamentação"
  - Corpo: "Esta resposta contém afirmações que não foram encontradas nos documentos consultados. Deseja promovê-la mesmo assim?"
  - Botões: [Cancelar] [Promover assim mesmo]
- Se confirma → chama `forcePromote(messageId)`
- Se cancela → reverte o like (chama `setFeedback(messageId, null)`)

---

## Task 6 — Testes + Commit

**Testes:**
1. `fidelity_checker_test.dart` — mock HTTP, grounded=true, grounded=false
2. `promotion_test.dart` — adicionar: checagem roda no like, skip em Qwen, verificador oposto, bloqueio/confirmação
3. `migration_v7_test.dart` — coluna verify_before_promote

---

## Verificação

- `flutter analyze` limpo
- `flutter test` passando
- Changelog fragment
- Commit

---

## Notas

- Sem coluna persistente em messages — resultado é pontual
- cache_control: ephemeral nos chunks para reduzir custo
- Toggle ligado por default em todas coleções novas
- Qwen local: skip sempre (sem segundo motor disponível)
