# Auditoria de Inicialização e Configuração — Dart Oráculo

**Data:** 2026-07-05  
**Problema reportado:** App pede senha ao abrir mesmo com toggle "Exigir Face ID / Touch ID" desligado.

---

## Diagnóstico

### O que NÃO é o problema:

- **LockScreen/AuthService** — biometria do app está **completamente desabilitada**:
  - `app.dart` linha 19: `initialRoute: AppRoutes.home` (pula LockScreen)
  - `lock_screen.dart` linha 29: `_authDisabled = true`
  - AuthService **nunca é chamado** na inicialização
  - Console confirma: nenhum log de AuthService ao abrir

### O que É o problema:

**O prompt de senha é do macOS Keychain, não do app.**

Quando `flutter_secure_storage` acessa o Keychain do macOS, o sistema operacional pode pedir autorização (senha do user) se:

1. **App sem code signing** — macOS não reconhece o binário como confiável
2. **Item do Keychain foi criado com permissão diferente** — antes do fix v0.17.1 (fallback removido), ou antes de adicionar `accessibility: first_unlock`
3. **Primeira execução após recompilação** — macOS trata cada build como app diferente

### Evidência no console:

```
INFO [SecureStorage] read(anthropic_api_key) → [SET]
INFO [SecureStorage] read(default_model) → null
```

**A leitura funciona** — mas antes dessas linhas aparecerem, o macOS mostra um dialog de "permitir acesso ao Keychain" que exige senha/Touch ID do sistema.

---

## Fluxo de Inicialização (atual)

```
main() → sqfliteFfiInit → Logger → runApp(DartOraculoApp)
    ↓
MaterialApp(initialRoute: home) → ChatScreen
    ↓
_ChatScreenState.initState → _initialize()
    ↓
SecureStorageService.getApiKey() → flutter_secure_storage.read(key)
    ↓
⚠️ macOS Keychain prompt (se item tem permissão restrita)
    ↓
read(anthropic_api_key) → [SET] (sucesso após user autorizar)
```

---

## Causa Raiz

| Fator | Impacto |
|---|---|
| `useDataProtectionKeyChain: false` | Usa Keychain genérico (não iCloud), mas ainda exige autorização por app |
| `accessibility: first_unlock` | Correto para evitar prompt DEPOIS do primeiro unlock, mas não resolve primeira execução pós-rebuild |
| Sem code signing em dev | macOS não confia no binário → pede senha na primeira leitura |
| Item Keychain criado antes do fix | Pode ter `accessControl` diferente do que o app agora espera |

---

## Soluções

### Solução 1 — Imediata (recomendada)

**Deletar itens antigos do Keychain** criados com permissões diferentes:

```bash
security delete-generic-password -a "dart_oraculo" -s "anthropic_api_key" 2>/dev/null
security delete-generic-password -a "dart_oraculo" -s "default_model" 2>/dev/null
security delete-generic-password -a "dart_oraculo" -s "biometric_enabled" 2>/dev/null
```

Na próxima execução, o app grava com as novas permissões (`first_unlock`) e não pede mais.

### Solução 2 — Code Signing (definitiva, para release)

Adicionar ao build de release:
- Certificate de Developer ID
- Provisioning profile
- `codesign --force --sign "Developer ID Application: ..." Runner.app`

Com signing, macOS confia no binário e não pede autorização do Keychain.

### Solução 3 — Fallback para UserDefaults em dev (não recomendada)

Usar `NSUserDefaults` em dev (sem encryption) — volta ao problema de segurança da v0.8.2.

---

## Sobre o Toggle "Exigir Face ID / Touch ID"

Esse toggle **NÃO controla o prompt do Keychain do macOS**. Ele controla apenas se o `LockScreen` do app exige biometria — que está desabilitado (`_authDisabled = true`).

O toggle na UI é enganoso no estado atual: parece que deveria impedir qualquer pedido de senha, mas o prompt que aparece é do **sistema operacional**, não do app.

### Recomendação UX:

Adicionar nota na UI:
> "Nota: Em modo desenvolvimento, o macOS pode pedir senha do sistema para acessar o Keychain. Isso é independente desta configuração."

Ou simplesmente esconder o toggle enquanto `_authDisabled = true`, já que não faz nada funcional.

---

## Entitlements

| Entitlement | Debug | Release | Nota |
|---|---|---|---|
| app-sandbox | **false** | true | Dev sem sandbox = sem restrição, mas Keychain ainda pede |
| network.client | true | true | OK |
| network.server | true | — | Só debug (DevTools) |
| device.audio-input | true | true | Speech |
| allow-jit | true | — | Só debug (Dart VM) |
| **keychain-access-groups** | **AUSENTE** | **AUSENTE** | Não necessário com useDataProtectionKeyChain:false |

---

## Ação Recomendada

1. **User executa**: `security delete-generic-password` para limpar itens antigos
2. **Código**: Esconder toggle de biometria enquanto `_authDisabled = true` (enganoso)
3. **Futuro**: Code signing resolve definitivamente

---

## Referência de Logs

Se o prompt do Keychain continuar aparecendo mesmo após deletar itens, os logs devem mostrar:
```
ERROR [SecureStorage] Keychain read falhou para "anthropic_api_key" ...
```

Se não aparecer ERROR = prompt foi aceito e leitura funcionou.
