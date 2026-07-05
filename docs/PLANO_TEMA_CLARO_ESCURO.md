# Plano de Implementação — Modo Diurno e Noturno

**Data:** 2026-07-05  
**Versão alvo:** v0.21.0  
**Escopo:** Suporte a tema claro (light) + escuro (dark) com toggle + persistência

---

## Visão Geral

O app hoje é dark-only. Vamos adicionar tema claro com paleta complementar, toggle no settings + persistência da preferência no SecureStorage.

**Melhor prática Flutter:** Usar `ThemeData` completo (light + dark) no `MaterialApp` com `themeMode` reativo, sem cores hardcoded nos widgets.

---

## Arquitetura

```
MaterialApp(
  theme: AppTheme.light,       // NOVO
  darkTheme: AppTheme.dark,    // EXISTENTE
  themeMode: themeNotifier.mode,  // NOVO: system / light / dark
)
```

**ThemeNotifier** (ChangeNotifier) persiste preferência em SecureStorage.

---

## Task 1 — Paleta de cores light

**Arquivo:** `lib/core/theme/app_colors.dart`

**Mudança:** Transformar `AppColors` em duas classes (ou usar extensão de ThemeData).

**Abordagem recomendada:** Manter `AppColors` para dark e criar `AppColorsLight` para light. MAS melhor prática Flutter é usar `Theme.of(context).colorScheme` em vez de constantes estáticas.

**Abordagem escolhida:** Definir cores via `ColorScheme` nos ThemeData e migrar widgets para usar `Theme.of(context)` onde possível. Manter `AppColors` apenas como referência de design tokens — NÃO usar diretamente nos widgets para cores que mudam entre temas.

**Cores light propostas:**
```dart
// Light palette
static const Color backgroundLight = Color(0xFFFAFAFA);
static const Color surfaceLight = Color(0xFFFFFFFF);
static const Color surfaceLightAlt = Color(0xFFF0F0F0);
static const Color textPrimaryLight = Color(0xFF1A1A1A);
static const Color textSecondaryLight = Color(0xFF5A5A5A);
static const Color textMutedLight = Color(0xFF9E9E9E);
static const Color dividerLight = Color(0xFFE0E0E0);
// Acento: mantém accentOrange (FF6B35) — funciona em ambos
```

---

## Task 2 — AppTheme.light + ThemeData completo

**Arquivo:** `lib/core/theme/app_theme.dart`

**Adicionar:**
```dart
static ThemeData get light => ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.backgroundLight,
  colorScheme: const ColorScheme.light(
    primary: AppColors.accentOrange,
    secondary: AppColors.accent,
    surface: AppColors.surfaceLight,
    error: AppColors.error,
    ...
  ),
  dividerColor: AppColors.dividerLight,
  textTheme: const TextTheme(
    // Mesmos styles mas com cores escuras
  ),
  ...
);
```

---

## Task 3 — ThemeNotifier + persistência

**Arquivo novo:** `lib/core/theme/theme_notifier.dart`

```dart
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier({required SecureStorageService storage}) : _storage = storage;
  
  final SecureStorageService _storage;
  ThemeMode _mode = ThemeMode.dark; // default: dark (comportamento atual)
  
  ThemeMode get mode => _mode;
  
  Future<void> load() async {
    final saved = await _storage.getThemeMode();
    _mode = saved ?? ThemeMode.dark;
    notifyListeners();
  }
  
  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    await _storage.setThemeMode(mode);
    notifyListeners();
  }
}
```

**SecureStorageService:** Adicionar `getThemeMode()` / `setThemeMode()`.

---

## Task 4 — Integrar no MaterialApp

**Arquivo:** `lib/app.dart`

```dart
class DartOraculoApp extends StatefulWidget {
  ...
}

class _DartOraculoAppState extends State<DartOraculoApp> {
  late ThemeNotifier _themeNotifier;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ThemeNotifier(storage: SecureStorageService());
    _themeNotifier.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeNotifier,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeNotifier.mode,
        ...
      ),
    );
  }
}
```

---

## Task 5 — Toggle no Settings

**Arquivo:** `lib/features/settings/settings_screen.dart`

Adicionar seção "Aparência" com 3 opções:
- ☀️ Claro
- 🌙 Escuro  
- 🖥️ Sistema (segue macOS)

Usando `SegmentedButton` ou `RadioListTile`.

---

## Task 6 — Migrar cores hardcoded dos widgets

**Problema:** Widgets usam `AppColors.surface`, `AppColors.background` diretamente. Em tema light, essas cores continuariam escuras.

**Solução:** Substituir nos widgets principais:
```dart
// Antes
color: AppColors.surface

// Depois
color: Theme.of(context).colorScheme.surface
```

**Widgets a migrar:**
- `chat_screen.dart` — toolbar, painel
- `sidebar.dart` — fundo
- `chat_input.dart` — container
- `message_bubble.dart` — bolhas
- `citation_strip.dart` — fundo
- `retry_bubble.dart` — fundo

**Nota:** Migração parcial OK — acento laranja e cores de contraste (text on surface) vêm do ColorScheme automaticamente.

---

## Task 7 — Manter AppColors para tema escuro como fallback

**Regra:** Qualquer widget que use `AppColors.xxx` diretamente funciona no dark. Para light, precisa usar `Theme.of(context)`. Migração progressiva — não obrigatório migrar tudo de uma vez.

---

## Task 8 — Testes

- Teste de ThemeNotifier (load, setMode, persistência)
- Teste que app renderiza em light sem crash
- Teste que app renderiza em dark sem crash

---

## Ordem de Execução

| # | Task | Esforço |
|---|---|---|
| 1 | Paleta light em AppColors | 15min |
| 2 | AppTheme.light completo | 30min |
| 3 | ThemeNotifier + storage | 30min |
| 4 | Integrar no MaterialApp | 15min |
| 5 | Toggle no Settings | 30min |
| 6 | Migrar cores hardcoded (principais) | 2h |
| 7 | Testes | 30min |

**Total estimado:** ~4h

---

## Decisões de Design

- **Default:** Dark (comportamento atual preservado)
- **Opção sistema:** Respeita `MediaQuery.platformBrightness`
- **Acento laranja:** Mantido em ambos temas (funciona em light e dark)
- **Migração:** Progressiva — widgets que não foram migrados continuam dark-only
- **Sem package externo:** Usa Flutter nativo (ThemeMode + ChangeNotifier)

---

## Verificação

- `flutter analyze` limpo
- `flutter test` passando  
- Changelog fragment
- Commit
- Build macOS: testar toggle visual light↔dark
