import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logger_service.dart';

/// Resultado de busca web.
class WebSearchResult {
  const WebSearchResult({
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String title;
  final String url;
  final String snippet;
}

/// Busca na internet via Brave Search API.
class WebSearchService {
  WebSearchService({required String apiKey, http.Client? httpClient})
      : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client();

  static const _tag = 'WebSearch';
  static const _baseUrl = 'https://api.search.brave.com/res/v1/web/search';
  final String _apiKey;
  final http.Client _httpClient;

  /// Busca [query] no Brave Search. Retorna até [count] resultados.
  Future<List<WebSearchResult>> search(String query, {int count = 5}) async {
    if (_apiKey.isEmpty) {
      LoggerService.instance.warn(_tag, 'Brave API key vazia — skip web search');
      return [];
    }

    LoggerService.instance.info(_tag, 'Buscando: "$query" (max $count)');

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'q': query,
        'count': count.toString(),
      });

      final response = await _httpClient.get(
        uri,
        headers: {
          'X-Subscription-Token': _apiKey,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        LoggerService.instance.error(_tag,
            'Brave API retornou ${response.statusCode}: ${response.body.substring(0, 100)}');
        return [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final web = json['web'] as Map<String, dynamic>?;
      final results = web?['results'] as List? ?? [];

      final parsed = results.take(count).map((r) {
        final item = r as Map<String, dynamic>;
        return WebSearchResult(
          title: item['title'] as String? ?? '',
          url: item['url'] as String? ?? '',
          snippet: item['description'] as String? ?? '',
        );
      }).toList();

      LoggerService.instance.info(_tag, '${parsed.length} resultados encontrados');
      return parsed;
    } catch (e) {
      LoggerService.instance.error(_tag, 'Erro na busca web', e);
      return [];
    }
  }
}
