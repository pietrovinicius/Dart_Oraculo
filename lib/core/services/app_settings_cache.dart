import 'logger_service.dart';
import 'secure_storage_service.dart';

/// Cache em memória de todas as chaves Keychain.
/// Batch read na inicialização → 1 autorização Keychain → N chaves carregadas.
class AppSettingsCache {
  static final AppSettingsCache _instance = AppSettingsCache._internal();
  factory AppSettingsCache() => _instance;
  AppSettingsCache._internal();

  static const _tag = 'AppSettingsCache';
  final Map<String, String?> _cache = {};
  bool _initialized = false;

  /// Batch read de todas as chaves do Keychain — 1 autorização, N chaves.
  /// Chamar uma única vez em main.dart antes de construir a app.
  Future<void> initialize(SecureStorageService storage) async {
    if (_initialized) {
      LoggerService.instance.info(_tag, 'Já inicializado, pulando');
      return;
    }

    LoggerService.instance.info(_tag, 'Iniciando batch read do Keychain...');

    try {
      // Batch read em paralelo — macOS agrupa em 1 prompt
      final results = await Future.wait([
        storage.readRaw('theme_mode'),
        storage.readRaw('text_scale'),
        storage.readRaw('chunk_max_tokens'),
        storage.readRaw('anthropic_api_key'),
        storage.readRaw('default_model'),
        storage.readRaw('kimi_api_key'),
        storage.readRaw('kimi_warning_dismissed'),
        storage.readRaw('general_knowledge_enabled'),
        storage.readRaw('verify_before_promote_enabled'),
        storage.readRaw('persist_zoom'),
        storage.readRaw('query_reformat_enabled'),
        storage.readRaw('max_history_messages'),
        storage.readRaw('max_chunks_per_query'),
      ]);

      _cache['theme_mode'] = results[0];
      _cache['text_scale'] = results[1];
      _cache['chunk_max_tokens'] = results[2];
      _cache['anthropic_api_key'] = results[3];
      _cache['default_model'] = results[4];
      _cache['kimi_api_key'] = results[5];
      _cache['kimi_warning_dismissed'] = results[6];
      _cache['general_knowledge_enabled'] = results[7];
      _cache['verify_before_promote_enabled'] = results[8];
      _cache['persist_zoom'] = results[9];
      _cache['query_reformat_enabled'] = results[10];
      _cache['max_history_messages'] = results[11];
      _cache['max_chunks_per_query'] = results[12];

      _initialized = true;
      LoggerService.instance
          .info(_tag, 'Batch read completo: ${_cache.length} chaves em cache');
    } catch (e) {
      LoggerService.instance.error(
        _tag,
        'Erro no batch read',
        e,
      );
      // Não rethrow — melhor que app quebre; apenas loga
      _initialized = false;
    }
  }

  /// Ler valor do cache. Retorna null se não inicializado ou chave ausente.
  String? get(String key) {
    if (!_initialized) {
      LoggerService.instance.warn(
        _tag,
        'Cache não inicializado, retornando null para "$key"',
      );
      return null;
    }
    return _cache[key];
  }

  /// Invalidar chave no cache após write — força releitura em próxima sessão.
  void invalidate(String key) {
    _cache.remove(key);
    LoggerService.instance.info(_tag, 'Cache invalidado: $key');
  }

  /// Verificar se inicializado (para testes).
  bool get isInitialized => _initialized;

  /// Debug: listar conteúdo do cache.
  Map<String, String?> get debugCache => Map.unmodifiable(_cache);
}
