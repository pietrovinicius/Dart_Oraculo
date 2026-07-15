# Auditoria UX: Erros Silenciosos no Dart Oráculo

**Data:** 2026-07-15  
**Escopo:** Todos os arquivos `.dart` em `lib/`  
**Objetivo:** Identificar exceções engolidas, operações que falham sem feedback UI, e data loss risks

---

## Resumo Executivo

**34 catch blocks auditados**
- **CRITICAL:** 1 → Data loss (tema não persiste)
- **HIGH:** 9 → Funcionalidades silenciosamente quebradas
- **MEDIUM:** 12 → Degradação sem aviso
- **LOW:** 12 → Proper error handling ou graceful fallback

**5 riscos mais perigosos (impacto no usuário):**
1. Tema escolhido não persiste no Keychain — usuário vê mudança, ao reiniciar volta ao padrão
2. Checagem de fidelidade (safety feature) é bypassed em erro — respostas não-fundamentadas passam
3. Re-indexação de documentos falha parcialmente mas reporta sucesso total
4. Autenticação falha retorna "failed" genérico — usuário não sabe por quê fica travado
5. Dedup de chunks RAG retorna array vazio silenciosamente — usuário vê "sem fontes" sem diagnóstico

---

## Achados Detalhados por Severidade

### 🔴 CRITICAL (User perde dados ou fica preso)

| Arquivo:Linha | Função | Problema | Impacto | Usuário experimenta |
|---|---|---|---|---|
| `theme_notifier.dart:31` | `setMode()` | `catch (_) {}` sem rethrow na escrita Keychain | Tema muda **em memória mas não persiste** | Escolhe tema escuro, reinicia app → volta para padrão. Sem aviso. |

**Por que é perigoso:** Silenciosa perda de preferência do usuário. Se Keychain falhar (raramente, mas pode), mudança de tema desaparece.

---

### 🟠 HIGH (Funcionalidades silenciosamente quebradas)

| Arquivo:Linha | Função | Problema | Impacto | Usuário experimenta |
|---|---|---|---|---|
| `chat_screen.dart:801` | `exportMarkdown()` — citations | `catch (_) {}` na montagem de citações | Export sucede mas **citations desaparecem** | Usuário exporta conversa → arquivo sem referências a documentos. Não sabe que citations faltam. |
| `fidelity_checker.dart:109` | `checkFidelity()` | `catch (e) { return FidelityCheckResult(isGrounded: true); }` — retorna "grounded=true" em erro | **Safety feature bypassed** — respostas não-fundamentadas passam | Usuário "promove" resposta não-verificada como conhecimento na RAG. Sistema degrada silenciosamente. |
| `document_service.dart:497` | `reindexAllDocuments()` | Loop continua em erro de doc individual; falha parcial reporta sucesso | **Re-indexação parcial silenciosa** | Usuário clica "re-index" → vê "sucesso". 30% dos docs não foram re-indexados. Descobre depois quando busca não funciona. |
| `auth_service.dart:62` | `authenticate()` | `catch (e, stack) { ... return AuthResult.failed; }` — sem mensagem de erro | Retorna "failed" genérico | Tela de lock fica travada sem explicação. Usuário não sabe se biometria quebrou, permissões negadas, ou outra coisa. |
| `chat_screen.dart:934` | `_dedupeChunks()` | `catch (_) { return []; }` — retorna array vazio em erro | **RAG retorna 0 chunks** → "sem fontes encontradas" | Usuário faz pergunta válida → vê "sem documentos relevantes" sem saber que dedup failed. |
| `query_reformatter_service.dart:42` | `reformatQuery()` | `catch (_) { return query; }` — fallback sem avisar | Reformador silenciosamente desabilitado | Query não é reformulada. Usuário recebe resultados piores sem saber por quê. |
| `chat_screen.dart:324` | `_buildCitationLabels()` | `catch (_) {}` na decodificação JSON de chunks | JSON inválido → citations = null | Mensagem exibida sem **nenhuma citação**, user não vê origem. |
| `kimi_service.dart:126` | `_parseDelta()` | `catch (_) { return null; }` em streaming | Linhas malformadas silenciosamente dropadas | Streaming Kimi mostra resposta **incompleta** sem indicador. |
| `web_search_service.dart:75` | `search()` | `catch (e) { ... return []; }` | Web search retorna vazio em erro | Usuário pensa "não há resultados web" vs "web search failed". Sem distinção. |

**Padrão comum:** Catch com log mas zero feedback na UI. Usuario nunca fica sabendo que algo falhou.

---

### 🟡 MEDIUM (Degradação sem aviso)

| Arquivo:Linha | Função | Problema | Impacto |
|---|---|---|---|
| `fidelity_checker.dart:127` | `_extractJson()` | `catch (_) { return null; }` em regex fallback | JSON null → fidelity check prossegue com claims=null |
| `app_settings_cache.dart:60` | `initialize()` | `catch (e) { _initialized = false; }` sem UI | Cache desabilitado → todos os reads vão direto ao Keychain. Lento. |
| `documents/document_service.dart:187` | `generateDescription()` | `catch (e) { return null; }` | Documento importa sem descrição gerada |
| `chat_screen.dart:497` | `_extractColumns()` | `catch (_) { return null; }` | Tabela perde headers; renderiza mal |
| `image_resize_service.dart:14` | `resize()` | `catch (_) { return bytes; }` | Redimensionamento falha → imagem oversized pode rejeitar |

---

### 🟢 LOW (Proper handling ou graceful fallback)

| Arquivo:Linha | Função | Status |
|---|---|---|
| `anthropic_service.dart:222` | `sendMessage()` | Throws com log — UI deve pegar via `_lastError` ✓ |
| `secure_storage_service.dart:103/120/137` | `_read()/_write()/_delete()` | Throws com mensagem descritiva ✓ |
| `chat_screen.dart:750/757` | `sendMessage()` — error handlers | Proper UI feedback via `setState(_lastError)` ✓ |
| `chat_screen.dart:873` | `_importDocuments()` | Coleta erros por arquivo, mostra resumo ao final ✓ |
| `ollama_service.dart:74/150` | `validateModelExists()/streamResponse()` | Throws com context; UI handles ✓ |
| `chat_screen.dart:167` | `_initialize()` — PackageInfo | Graceful fallback (hardcoded version label) ✓ |

---

## Padrões de Anti-Padrão Identificados

### 1. **Catch Vazio**
```dart
// ❌ ANTI-PADRÃO
try {
  await updateTheme(mode);
} catch (_) {
  // Nada. Theme muda em memória, não persiste.
}
```
✅ **Correto:**
```dart
try {
  await updateTheme(mode);
} catch (e) {
  LoggerService.error('theme', 'Falha ao persister tema', e);
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erro ao salvar tema: ${e.toString()}'))
    );
  }
  rethrow; // Ou return early com state degradado
}
```

### 2. **Log-Only Error (User nunca fica sabendo)**
```dart
// ❌ ANTI-PADRÃO
try {
  final result = await reformatQuery(question);
} catch (e) {
  LoggerService.warn('QueryReformatter', 'Reformulação falhou: $e');
  return question; // Silencioso fallback
}
```
✅ **Correto:**
```dart
try {
  final result = await reformatQuery(question);
} catch (e) {
  LoggerService.warn('QueryReformatter', 'Reformulação falhou: $e');
  // Opção 1: Rethrow para bubbling + UI handling
  // Opção 2: Notificar user inline: "usando busca padrão"
  // Opção 3: Métricas/analytics para debugar degradação
  return question; // Se fallback silencioso, marcar em logs para monitorar
}
```

### 3. **Retorno Default em Erro (Data loss ou breaking)**
```dart
// ❌ ANTI-PADRÃO
try {
  return dedupeChunks(results);
} catch (_) {
  return []; // RAG fica vazio
}
```
✅ **Correto:**
```dart
try {
  return dedupeChunks(results);
} catch (e) {
  LoggerService.error('Dedup', 'Failed to dedupe chunks', e);
  // Opção 1: Rethrow (fail loud)
  // Opção 2: Return input unchanged (dedup skipped, not silent)
  // Opção 3: Return + set UI error state
  return results; // Skip dedup, explicitar que dedup foi pulado
}
```

### 4. **Bypassing Safety Checks em Erro**
```dart
// ❌ ANTI-PADRÃO
try {
  return checkFidelity(response);
} catch (e) {
  return FidelityCheckResult(isGrounded: true); // PERIGOSO — bypassa segurança
}
```
✅ **Correto:**
```dart
try {
  return checkFidelity(response);
} catch (e) {
  LoggerService.error('Fidelity', 'Check falhou', e);
  // Nunca bypasse safety. Sempre falhar safe (conservador):
  return FidelityCheckResult(isGrounded: false, reason: 'Fidelity check indisponível');
  // Ou rethrow + marcar resposta como "não verificado"
}
```

### 5. **Partial Failure sem Diagnóstico**
```dart
// ❌ ANTI-PADRÃO
for (final doc in documents) {
  try {
    await reindexDoc(doc);
  } catch (_) {
    // Skip e continue — usuário vê \"sucesso\" ao final
  }
}
```
✅ **Correto:**
```dart
final failures = <String>[];
for (final doc in documents) {
  try {
    await reindexDoc(doc);
  } catch (e) {
    failures.add('${doc.name}: $e');
  }
}
if (failures.isNotEmpty) {
  LoggerService.warn('Reindex', 'Falhas em ${failures.length} docs: $failures');
  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Re-indexação parcial: ${failures.length} docs falharam'))
    );
  }
}
```

---

## Checklist UX: Quando Catch é Aceitável

Cada catch deve responder SIM para **pelo menos 2** destas perguntas:

- [ ] Há UI feedback (SnackBar, dialog, setState com mensagem)?
- [ ] Há logging estruturado (não só `log()`)?
- [ ] Há fallback explícito documentado (comentário: "dedup pulado, usando input bruto")?
- [ ] É graceful degradation (funcionalidade continua, apenas degradada)?
- [ ] Há monitoramento/metrics para detectar recorrência?
- [ ] Erro é rethrown para bubbling + tratamento upstream?

Se responder NÃO para TODOS, é um catch silencioso — **REFATOR NECESSÁRIO.**

---

## Próximos Passos

Ver arquivo de plano de implementação: `PLANO_ELIMINACAO_ERROS_SILENCIOSOS.md`
