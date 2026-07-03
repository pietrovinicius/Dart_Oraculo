import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Exceção para erros da API Anthropic.
class AnthropicException implements Exception {
  const AnthropicException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'AnthropicException($statusCode): $message';
}

/// Cliente HTTP direto para api.anthropic.com/v1/messages.
class AnthropicService {
  AnthropicService({
    required String apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client();

  final String _apiKey;
  final http.Client _httpClient;

  /// Constrói headers para a API.
  Map<String, String> buildHeaders() => {
    'x-api-key': _apiKey,
    'anthropic-version': AppConfig.anthropicVersion,
    'content-type': 'application/json',
  };

  /// Monta o body da request.
  Map<String, dynamic> buildRequestBody({
    required String userMessage,
    required String context,
    required List<Map<String, String>> history,
    required String model,
  }) {
    final systemPrompt = 'Você é o Oráculo, um assistente de conhecimento pessoal. '
        'Responda com base exclusivamente no contexto fornecido abaixo. '
        'Se a informação não estiver no contexto, diga que não encontrou nos documentos.\n\n'
        '--- CONTEXTO ---\n$context\n--- FIM DO CONTEXTO ---';

    final messages = <Map<String, dynamic>>[
      ...history,
      {'role': 'user', 'content': userMessage},
    ];

    return {
      'model': model,
      'max_tokens': 4096,
      'stream': true,
      'system': systemPrompt,
      'messages': messages,
    };
  }

  /// Parseia um evento SSE do stream.
  /// Retorna o texto delta ou null se não for um evento de texto.
  String? parseStreamEvent(String line) {
    if (line.isEmpty || !line.startsWith('data: ')) return null;

    final data = line.substring(6).trim();
    if (data == '[DONE]' || data.isEmpty) return null;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      if (json['type'] == 'content_block_delta') {
        final delta = json['delta'] as Map<String, dynamic>;
        if (delta['type'] == 'text_delta') {
          return delta['text'] as String;
        }
      }
    } on FormatException {
      // Ignora linhas que não são JSON válido
    }

    return null;
  }

  /// Envia mensagem e retorna stream de tokens da resposta.
  Stream<String> sendMessage({
    required String userMessage,
    required String context,
    required List<Map<String, String>> history,
    required String model,
  }) async* {
    final body = buildRequestBody(
      userMessage: userMessage,
      context: context,
      history: history,
      model: model,
    );

    final response = await _httpClient.post(
      Uri.parse(AppConfig.anthropicBaseUrl),
      headers: buildHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      String errorMessage;
      try {
        final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
        final error = errorJson['error'] as Map<String, dynamic>?;
        errorMessage = error?['message'] as String? ?? response.body;
      } on FormatException {
        errorMessage = response.body;
      }
      throw AnthropicException(errorMessage, response.statusCode);
    }

    final lines = response.body.split('\n');
    for (final line in lines) {
      final text = parseStreamEvent(line);
      if (text != null) {
        yield text;
      }
    }
  }
}
