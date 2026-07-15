# Plano de Implementação: Eliminar Erros Silenciosos

**Objetivo:** Implementar feedback UI obrigatório para toda falha, eliminar catch vazios, e estabelecer padrão de "fail loud not silent".

---

## Estratégia Geral

### 1. **Error Feedback Service (novo)**

Criar serviço centralizado para feedback de erro — garante consistência e facilita testes:

```dart
// lib/core/services/error_feedback_service.dart
class ErrorFeedbackService {
  static void showError(
    BuildContext context,
    String title,
    String message, {
    bool isPersistent = false,
  }) {
    if (!context.mounted) return;
    
    if (isPersistent) {
      // Dialog para erros críticos
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [Button(label: 'OK', onPressed: () => Navigator.pop(context))],
        ),
      );
    } else {
      // SnackBar para degradações
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $message'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  static void showWarning(BuildContext context, String message) {
    showError(context, 'Aviso', message, isPersistent: false);
  }

  static void showCriticalError(BuildContext context, String message) {
    showError(context, 'Erro Crítico', message, isPersistent: true);
  }
}
```

### 2. **Error Categories (Enum)**

```dart
enum ErrorSeverity {
  info,      // Apenas log
  warning,   // SnackBar não-persistente
  error,     // SnackBar persistente ou dialog
  critical,  // Modal dialog + estado degradado
}
```

### 3. **Refator Pattern**

Todos os catch mudam assim:

```dart
// ANTES
try {
  await operation();
} catch (_) {
  // Nada
}

// DEPOIS
try {
  await operation();
} catch (e) {
  LoggerService.error('Feature', 'Operation falhou', e);
  if (mounted) {
    ErrorFeedbackService.showError(
      context,
      'Falha na operação',
      'Detalhes: ${e.toString()}',
    );
  }
  rethrow; // Ou setState error + return early
}
```

---

## Implementação por Prioridade

### 🔴 **P0: CRITICAL (Data Loss Risk) — Sprint 1**

#### Task 1.1: `theme_notifier.dart:31` — Tema não persiste

**Arquivo:** `lib/core/theme/theme_notifier.dart`  
**Função:** `setMode(ThemeMode mode)`  
**Mudança:**

```dart
Future<void> setMode(ThemeMode mode) async {
  _mode = mode;
  notifyListeners(); // Update imediatamente na UI
  
  try {
    await _storage.writeRaw(_key, _toString(mode));
    LoggerService.info(_tag, 'Tema persistido: $_mode');
  } catch (e) {
    LoggerService.error(_tag, 'Falha ao persistir tema', e);
    // Revert state
    _mode = _lastSuccessfulMode;
    notifyListeners();
    
    // Notify user — CRÍTICO para data loss awareness
    if (context != null && context!.mounted) {
      ErrorFeedbackService.showCriticalError(
        context!,
        'Tema não foi salvo. Reinicie o app para recuperar preferência anterior.',
      );
    }
    rethrow;
  }
  _lastSuccessfulMode = mode;
}
```

**Teste:**
- Mock `SecureStorageService.write()` para throw
- Verificar que state reverte
- Verificar que dialog exibido

---

### 🟠 **P1: HIGH (Functional Breakage) — Sprint 1**

#### Task 1.2: `fidelity_checker.dart:109` — Safety Check Bypassed (CRITICAL for safety)

**Arquivo:** `lib/core/services/fidelity_checker.dart`  
**Função:** `checkFidelity(String response)`  
**Mudança:**

```dart
Future<FidelityCheckResult> checkFidelity(String response) async {
  try {
    // ... existing logic ...
    return result;
  } catch (e) {
    LoggerService.error(
      _tag,
      'Fidelity check falhou — defaultando para CONSERVADOR',
      e,
    );
    
    // NUNCA bypasse safety check. Sempre falhar conservador:
    return const FidelityCheckResult(
      isGrounded: false,
      reason: 'Verificação de fidelidade indisponível. Resposta não verificada.',
      ungroundedClaims: [], // Empty → força usuário a revisar manualmente
    );
    // NÃO rethrow — fidelity check é addon, não bloqueante
  }
}
```

**Teste:**
- Mock LLM para throw
- Verificar que retorna `isGrounded: false` (conservador)
- Verificar que reason exibido ao usuário em UI

---

#### Task 1.3: `document_service.dart:497` — Partial Reindex Failure

**Arquivo:** `lib/features/documents/document_service.dart`  
**Função:** `reindexAllDocuments()`  
**Mudança:**

```dart
Future<ReindexResult> reindexAllDocuments() async {
  final failures = <ReindexFailure>[];
  int successCount = 0;
  
  for (final doc in await getAllDocuments()) {
    try {
      await _reindexDocument(doc);
      successCount++;
    } catch (e) {
      LoggerService.error('DocumentService', 'Reindex falhou para ${doc.name}', e);
      failures.add(ReindexFailure(docName: doc.name, error: e.toString()));
    }
  }
  
  // Retorna resultado COMPLETO — sucesso E falhas
  return ReindexResult(
    successCount: successCount,
    failureCount: failures.length,
    failures: failures,
  );
}

// No ChatScreen, mostrar resultado:
Future<void> _reindexDocuments() async {
  final result = await _documentService.reindexAllDocuments();
  
  if (mounted) {
    if (result.failureCount == 0) {
      ErrorFeedbackService.showWarning(
        context,
        'Todos os ${result.successCount} documentos foram re-indexados.',
      );
    } else {
      ErrorFeedbackService.showError(
        context,
        'Re-indexação Parcial',
        '${result.successCount} sucesso, ${result.failureCount} falharam: ${result.failures.map((f) => f.docName).join(", ")}',
        isPersistent: true,
      );
    }
  }
}
```

**Classe auxiliar:**
```dart
class ReindexFailure {
  final String docName;
  final String error;
  ReindexFailure({required this.docName, required this.error});
}

class ReindexResult {
  final int successCount;
  final int failureCount;
  final List<ReindexFailure> failures;
  ReindexResult({required this.successCount, required this.failureCount, required this.failures});
}
```

---

#### Task 1.4: `auth_service.dart:62` — Auth Failure without Diagnosis

**Arquivo:** `lib/features/auth/auth_service.dart`  
**Função:** `authenticate()`  
**Mudança:**

```dart
Future<AuthResult> authenticate() async {
  try {
    // ... existing logic ...
    return AuthResult.success();
  } on Exception catch (e, stack) {
    LoggerService.error('Auth', 'authenticate() falhou', e);
    
    // Retorna result COM mensagem diagnóstica
    final message = _authErrorMessage(e);
    return AuthResult.failed(message: message);
  }
}

String _authErrorMessage(Exception e) {
  if (e is PlatformException) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometria não disponível neste dispositivo.';
      case 'NotEnrolled':
        return 'Nenhuma biometria cadastrada. Adicione no sistema.';
      case 'LockedOut':
        return 'Muitas tentativas. Tente novamente em alguns minutos.';
      case 'UserCanceled':
        return 'Autenticação cancelada.';
      default:
        return 'Falha na autenticação: ${e.message}';
    }
  }
  return 'Erro desconhecido na autenticação: $e';
}

// No LockScreen, mostrar mensagem:
if (result.isFailed) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.message ?? 'Autenticação falhou')),
  );
}
```

---

#### Task 1.5: `chat_screen.dart:934` — RAG Dedup Failure Silent

**Arquivo:** `lib/features/chat/chat_controller.dart` (where dedup happens)  
**Função:** `_dedupeChunks(List<SearchResult> results)`  
**Mudança:**

```dart
List<SearchResult> _dedupeChunks(List<SearchResult> results) {
  try {
    // ... dedup logic ...
    return deduped;
  } catch (e) {
    LoggerService.error(
      _tag,
      'Dedup falhou — usando resultados brutos (não-dedup)',
      e,
    );
    // NUNCA retorna vazio. Sempre retorna input se dedup falha:
    return results; // Dedup skipped — melhor ter duplicatas do que vazio
  }
}

// No ChatScreen, detectar dedup skip:
if (ftsResults.length == totalFtsResults) {
  // Dedup não removeu nada → pode ter falhado
  LoggerService.warn('Chat', 'Dedup pode ter sido skipped — chunks não-dedup');
}
```

---

#### Task 1.6: `chat_screen.dart:801` — Export Citations Missing

**Arquivo:** `lib/features/chat/chat_screen.dart`  
**Função:** `_exportMarkdown()`  
**Mudança:**

```dart
Future<void> _exportMarkdown() async {
  final citations = <String>[];
  
  for (final msg in _messages) {
    if (msg.chunksUsed.isEmpty) continue;
    
    try {
      final citationText = await _buildCitationText(msg);
      citations.add(citationText);
    } catch (e) {
      LoggerService.error('Export', 'Falha ao montar citação para msg ${msg.id}', e);
      citations.add('⚠️ Citação indisponível: $e');
      // NÃO pula — inclui aviso visual
    }
  }
  
  if (citations.isEmpty && _messages.isNotEmpty) {
    if (mounted) {
      ErrorFeedbackService.showWarning(
        context,
        'Nenhuma citação pôde ser exportada. Verifique o arquivo.',
      );
    }
  }
  
  // ... continue export ...
}
```

---

### 🟡 **P2: MEDIUM (Degradation) — Sprint 2**

#### Task 2.1: `query_reformatter_service.dart:42` — Silent Fallback

**Mudança:** Adicionar metrics/logging para detectar degradação

```dart
Future<String> reformatQuery(String query) async {
  try {
    final result = await _reformatWithLLM(query);
    return result;
  } catch (e) {
    LoggerService.warn('QueryReformatter', 'Reformulação skipped: $e');
    _metrics.incrementDegradedQueries();
    return query; // Fallback silencioso OK se há metrics
  }
}
```

#### Task 2.2: `web_search_service.dart:75` — Empty Search Results

```dart
Future<List<WebResult>> search(String query) async {
  try {
    final results = await _braveApi.search(query);
    return results;
  } catch (e) {
    LoggerService.error('WebSearch', 'Search failed: $e');
    return []; // OK se documentado como "no results, não failure"
    // OU rethrow para catching upstream
  }
}
```

---

## Implementation Timeline

| Sprint | Tasks | Estimate | Owner |
|--------|-------|----------|-------|
| **1** | ErrorFeedbackService + P0 tasks (1-6) | 3-4 days | Dev |
| **2** | P1 async cleanup + P2 degradation handling | 2-3 days | Dev |
| **3** | Testing + documentation | 2 days | QA + Dev |
| **4** | Monitoring/metrics setup | 1-2 days | DevOps |

---

## Code Review Checklist (Per PR)

Antes de merge, verificar:

- [ ] Nenhum `catch (_) {}` ou `catch (e) {}` vazio
- [ ] Todo catch tem `LoggerService.error()` ou `LoggerService.warn()`
- [ ] Se há UI, catch chama `ErrorFeedbackService.show*()`
- [ ] Se há fallback, está documentado em comentário (por quê fallback é seguro)
- [ ] Se retorna valor default, valor não é "vazio" (ex: `[]`, `null` sem aviso)
- [ ] Safety checks nunca são bypassadas (ex: fidelity check sempre conservador)
- [ ] Partial failures retornam resultado completo (sucesso + falhas), não apenas sucesso

---

## Acceptance Criteria

Um erro é "tratado bem" quando:

✅ **Usuário fica informado** via UI (SnackBar, dialog, ou status widget)  
✅ **Log estruturado** para debugging (arquivo:linha, tipo de erro, stack)  
✅ **Fallback documentado** (comentário explicando por quê fallback é seguro)  
✅ **Sem data loss** (estado revertes ou persiste com aviso)  
✅ **Safety preserved** (checks críticas não são bypassadas)  
✅ **Testável** (mock de erro funciona, UI feedback verificável)  

---

## Monitoring & Metrics

Adicionar ao app:

```dart
class ErrorMetrics {
  static final instance = ErrorMetrics._();
  ErrorMetrics._();
  
  final Map<String, int> _errorCounts = {};
  
  void recordError(String category) {
    _errorCounts[category] = (_errorCounts[category] ?? 0) + 1;
  }
  
  void reportToAnalytics() {
    _errorCounts.forEach((category, count) {
      // Send to analytics/Sentry/monitoring
      LoggerService.info('Metrics', '$category: $count occurrences');
    });
  }
}

// Usage:
ErrorMetrics.instance.recordError('theme_persistence_failed');
```

Permite detectar silent errors em produção via anomaly detection.

---

## Rollback Plan

Se implementação causar issues:

1. Disable ErrorFeedbackService via feature flag
2. Revert catch blocks para log-only (sem UI blast)
3. Keep new error categories + metrics
4. Iterate com fewer components

---

## Success Criteria (End of Sprint 4)

- ✅ **Zero critical silent failures** (P0 todos done)
- ✅ **90%+ catch blocks have UI feedback** (P1+P2 coverage)
- ✅ **Logging structured + queryable** (category + timestamp + stack)
- ✅ **Monitoring dashboard live** (error trends visible)
- ✅ **Test coverage 80%+** for error paths
- ✅ **User testing**: "Errors are never silent" feedback from beta testers
