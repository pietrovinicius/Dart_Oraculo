import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logger_service.dart';
import 'secure_storage_service.dart';

/// Reformula queries confusas do usuário via LLM antes de enviar ao FTS5.
/// Timeout 2s, cache 1h, fallback para query original.
class QueryReformatterService {
  QueryReformatterService({
    http.Client? httpClient,
    SecureStorageService? storage,
  })  : _httpClient = httpClient ?? http.Client(),
        _storage = storage ?? SecureStorageService();

  static const _tag = 'QueryReformat';
  static const _timeout = Duration(seconds: 2);
  static const _cacheTtl = Duration(hours: 1);
  static const _model = 'claude-haiku-4-5-20251001';
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';

  final http.Client _httpClient;
  final SecureStorageService _storage;

  // Cache em memória: query → (resultado, timestamp)
  final Map<String, _CacheEntry> _cache = {};

  /// Reformula [query] em termos limpos para busca textual.
  /// Retorna query original se:
  /// - Timeout (2s)
  /// - Sem API key
  /// - Erro na API
  /// - Toggle desabilitado
  /// - Query já é curta/limpa (≤ 3 palavras sem stopwords)
  Future<String> reformat(String query) async {
    // Verifica se toggle está habilitado
    String? enabled;
    try {
      enabled = await _storage.readRaw('query_reformat_enabled');
    } catch (_) {
      // SecureStorage indisponível (testes sem bindings) → fallback
      return query;
    }
    if (enabled == 'false') {
      LoggerService.instance.info(_tag, 'Toggle desabilitado — query original');
      return query;
    }

    // Cache hit?
    final cached = _cache[query];
    if (cached != null && DateTime.now().difference(cached.timestamp) < _cacheTtl) {
      LoggerService.instance.info(_tag, 'Cache hit: "$query" → "${cached.result}"');
      return cached.result;
    }

    // Query curta demais → não precisa reformular
    final words = query.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (words.length <= 3) {
      LoggerService.instance.info(_tag, 'Query curta (${words.length} termos) — sem reformulação');
      return query;
    }

    // Obtém API key
    final apiKey = await _storage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      LoggerService.instance.warn(_tag, 'Sem API key — fallback para original');
      return query;
    }

    try {
      final result = await _callLlm(query, apiKey).timeout(_timeout);
      // Valida resultado
      if (result.isEmpty || result.length > query.length * 2) {
        LoggerService.instance.warn(_tag, 'Resultado inválido — fallback');
        return query;
      }
      // Cacheia
      _cache[query] = _CacheEntry(result: result, timestamp: DateTime.now());
      LoggerService.instance.info(_tag, 'Reformulado: "$query" → "$result"');
      return result;
    } on TimeoutException {
      LoggerService.instance.warn(_tag, 'Timeout (2s) — fallback para original');
      return query;
    } catch (e) {
      LoggerService.instance.warn(_tag, 'Erro: $e — fallback para original');
      return query;
    }
  }

  Future<String> _callLlm(String query, String apiKey) async {
    final body = jsonEncode({
      'model': _model,
      'max_tokens': 100,
      'messages': [
        {
          'role': 'user',
          'content': query,
        },
      ],
      'system': 'Você é um reformulador de queries para busca textual em banco de documentos.\n'
          'Dada a pergunta do usuário, retorne APENAS os termos-chave para busca.\n'
          'Regras:\n'
          '- Remova filler ("pesquisa", "me ajuda", "quero saber", "então", "por favor").\n'
          '- Corrija erros ortográficos.\n'
          '- Mantenha termos técnicos, siglas e códigos intactos (CID, SQL, nomes de tabelas).\n'
          '- Se houver código colado, extraia apenas a intenção (ex: "erro de ambiguidade em JOIN").\n'
          '- Máximo 5 termos na resposta.\n'
          '- Responda APENAS os termos separados por espaço, nada mais.',
    });

    final response = await _httpClient.post(
      Uri.parse(_baseUrl),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception('API retornou ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final content = json['content'] as List<dynamic>;
    if (content.isEmpty) return '';
    final text = (content.first as Map<String, dynamic>)['text'] as String? ?? '';
    return text.trim();
  }

  /// Limpa cache expirado.
  void clearExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere((_, entry) => now.difference(entry.timestamp) >= _cacheTtl);
  }
}

class _CacheEntry {
  const _CacheEntry({required this.result, required this.timestamp});
  final String result;
  final DateTime timestamp;
}
