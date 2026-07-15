# Plano: Reduzir Solicitações de Senha Keychain para Uma Única Vez

## Problema

Ao abrir o app, macOS solicita a senha do usuário **7+ vezes** em sequência:
- `read(theme_mode)`
- `read(text_scale)`
- `read(chunk_max_tokens)`
- `read(anthropic_api_key)`
- `read(default_model)`
- `read(kimi_api_key)`
- `read(kimi_warning_dismissed)`

**Raiz:** Cada `await` no `_read()` força uma nova sessão Keychain → novo prompt.

## Solução: Batch Read + Memory Cache

Strategy: 1 autorização Keychain para N chaves via **batch read** na inicialização, depois cache em memória.

### Fase 1: Batch Read Service

Criar `AppSettingsCache` — carrega todas as chaves de uma vez no `main.dart`:

```dart
class AppSettingsCache {
  // Singleton com cache em memória
  static final AppSettingsCache _instance = AppSettingsCache._internal();
  factory AppSettingsCache() => _instance;
  AppSettingsCache._internal();

  final Map<String, String?> _cache = {};
  bool _initialized = false;

  Future<void> initialize(SecureStorageService storage) async {
    if (_initialized) return;
    
    // Batch read todas as chaves em paralelo → 1 Keychain unlock
    final results = await Future.wait([
      storage.readRaw('theme_mode'),
      storage.readRaw('text_scale'),
      storage.readRaw('chunk_max_tokens'),
      storage.readRaw('anthropic_api_key'),
      storage.readRaw('default_model'),
      storage.readRaw('kimi_api_key'),
      storage.readRaw('kimi_warning_dismissed'),
      // Mais chaves conforme necessário
    ]);

    _cache['theme_mode'] = results[0];
    _cache['text_scale'] = results[1];
    _cache['chunk_max_tokens'] = results[2];
    _cache['anthropic_api_key'] = results[3];
    _cache['default_model'] = results[4];
    _cache['kimi_api_key'] = results[5];
    _cache['kimi_warning_dismissed'] = results[6];

    _initialized = true;
    LoggerService.instance.info('AppSettingsCache', 'Inicializado com ${_cache.length} chaves');
  }

  String? get(String key) => _cache[key];

  void invalidate(String key) {
    _cache.remove(key);
  }
}
```

### Fase 2: Atualizar main.dart

Carregar cache **antes** de construir a árvore de widgets:

```dart
void main() async {
  // ... setup existente ...
  
  // Batch read Keychain — uma única autorização
  await AppSettingsCache().initialize(SecureStorageService());
  
  runApp(const DartOraculoApp());
}
```

### Fase 3: Atualizar Consumers

**ThemeNotifier.load():**
```dart
Future<void> load() async {
  final cached = AppSettingsCache().get('theme_mode');
  _mode = _fromString(cached); // Lê do cache, não do Keychain
  notifyListeners();
}
```

**SettingsController.load():**
```dart
Future<void> load() async {
  _apiKey = AppSettingsCache().get('anthropic_api_key') ?? '';
  _selectedModel = AppSettingsCache().get('default_model') ?? AppConfig.defaultModel;
  // Não faz read() — usa cache
  notifyListeners();
}
```

**SettingsScreen._loadKimiKey():**
```dart
Future<void> _loadKimiKey() async {
  final key = AppSettingsCache().get('kimi_api_key');
  if (key != null && key.isNotEmpty && mounted) {
    setState(() => _kimiKeyController.text = _maskApiKey(key));
  }
}
```

### Fase 4: Invalidação de Cache

Quando usuário **escreve** uma chave em Settings, invalidar cache local:

```dart
Future<void> saveModel(String model) async {
  _selectedModel = model;
  await _storageService.setDefaultModel(model);
  AppSettingsCache().invalidate('default_model'); // Força releitura na próxima abertura
  notifyListeners();
}
```

## Resultado Esperado

- ✅ Primeira abertura: macOS pede senha **1 vez**, Keychain autoriza batch, cache carrega
- ✅ Acessos subsequentes: leem cache em memória, sem prompts
- ✅ Escrita: atualiza Keychain + invalida cache
- ✅ Próxima abertura: relê Keychain (1 autorização), cache refill

## Implementação Order

1. Criar `AppSettingsCache` (novo arquivo)
2. Atualizar `main.dart` com `AppSettingsCache().initialize()`
3. Atualizar `ThemeNotifier.load()`
4. Atualizar `SettingsController.load()`
5. Atualizar `SettingsScreen._loadKimiKey()` e outras funções de leitura
6. Adicionar `invalidate()` em todos os `save*()` methods
7. Executar testes
8. Commit + changelog

## Notas

- Cache vive apenas em memória — não persiste entre runs
- Escrever no Keychain continua individual (não é gargalo)
- Se estrutura crescer, migrar cache para SQLite com TTL
