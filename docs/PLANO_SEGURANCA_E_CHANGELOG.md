# Plano de Implementação — Segurança + Consolidação Changelog

**Data:** 2026-07-05  
**Versão alvo:** v0.17.1 (hotfix segurança) + v0.17.0 (consolidação)

---

## Task 1 — SEGURANÇA: Remover fallback texto plano (PRIORIDADE MÁXIMA)

**Arquivo:** `lib/core/services/secure_storage_service.dart`

**Problema:** Quando Keychain falha, API key é gravada em `.secure_store.json` sem criptografia.

**Fix:** Remover todo o file-based fallback. Falha de Keychain → erro visível ao user.

**Mudanças:**
- Remover `_useFileFallback`, `_fileCache`, `_getFallbackFile`, `_loadFileStore`, `_saveFileStore`, `_readFromFile`, `_writeToFile`, `_deleteFromFile`
- Nos catch de `_read`/`_write`/`_delete`: re-throw com mensagem clara
- Remover import de `dart:convert`, `dart:io`, `path_provider` se não mais usados
- Changelog fragment: `changelog_v0.17.1_2026-07-05_remove-plaintext-fallback.md`

---

## Task 2 — Consolidar v0.17.0 no CHANGELOG.md

Adicionar entrada v0.17.0 ao topo do CHANGELOG.md com formato Keep a Changelog.

---

## Task 3 — Verificar auditoria v0.13.2 vs bug OR

Ler `docs/auditoria_v0.13.2_2026-07-04.md`, identificar quais achados eram sintoma do OR.

---

## Task 4 — Busca híbrida já implementada

Verificar que AND→OR fallback já existe (commit f4d8aaa). Testar com prosa narrativa.

---

## Task 5 — Colar texto exato do prompt no changelog

Ler prompt atual de anthropic_service.dart e incluir no changelog v0.17.0.

---
