import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/image_attachment.dart';
import 'generation_service.dart';
import 'logger_service.dart';

/// Exceção para erros da API Kimi (Moonshot).
class KimiException implements Exception {
  const KimiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'KimiException($statusCode): $message';
}

/// Motor de geração via Kimi K2.6 (Moonshot AI).
/// API compatível com formato OpenAI (messages + streaming SSE).
class KimiService implements GenerationService {
  KimiService({
    required String apiKey,
    http.Client? httpClient,
    this.model = AppConfig.kimiModel,
    this.baseUrl = AppConfig.kimiBaseUrl,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client();

  static const _tag = 'KimiService';
  final String _apiKey;
  final String model;
  final String baseUrl;
  final http.Client _httpClient;

  @override
  String get modelDisplayName => 'Kimi K2.6';

  @override
  int get maxContextCharsPerChunk => 80000;

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String question,
    List<ImageAttachment>? images,
    bool allowGeneralKnowledge = false,
  }) async* {
    if (_apiKey.isEmpty) {
      throw const KimiException('Chave Kimi não configurada.', 0);
    }

    LoggerService.instance.info(_tag,
        'streamResponse() → model=$model, apiKey=configurada (${_apiKey.length} chars)');

    // Monta messages no formato OpenAI
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': question},
    ];

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
      'max_tokens': 4096,
    });

    LoggerService.instance.info(_tag, 'POST $baseUrl');

    final request = http.Request('POST', Uri.parse(baseUrl))
      ..headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      })
      ..body = body;

    final streamedResponse = await _httpClient.send(request)
        .timeout(AppConfig.httpTimeout);

    LoggerService.instance.info(_tag,
        'response.statusCode=${streamedResponse.statusCode}');

    if (streamedResponse.statusCode != 200) {
      final responseBody = await streamedResponse.stream.bytesToString();
      final errorMsg = _parseError(responseBody, streamedResponse.statusCode);
      throw KimiException(errorMsg, streamedResponse.statusCode);
    }

    // Parse streaming SSE (formato OpenAI)
    final lineStream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      final token = _parseStreamLine(line);
      if (token != null) yield token;
    }

    LoggerService.instance.info(_tag, 'streamResponse() completo com sucesso');
  }

  /// Parseia uma linha SSE no formato OpenAI.
  /// Retorna o token de texto ou null se não é content.
  String? _parseStreamLine(String line) {
    if (line.isEmpty || !line.startsWith('data: ')) return null;

    final data = line.substring(6).trim();
    if (data == '[DONE]') return null;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>?;
      if (choices == null || choices.isEmpty) return null;

      final delta = (choices.first as Map<String, dynamic>)['delta']
          as Map<String, dynamic>?;
      if (delta == null) return null;

      return delta['content'] as String?;
    } catch (_) {
      // Linha malformada — ignora silenciosamente
      return null;
    }
  }

  /// Extrai mensagem de erro do body de resposta.
  String _parseError(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;
      if (error != null) {
        return error['message'] as String? ?? 'Erro desconhecido ($statusCode)';
      }
    } catch (_) {
      // Body não é JSON
    }

    if (statusCode == 401) return 'Chave Kimi inválida ou expirada.';
    if (statusCode == 429) return 'Rate limit Kimi excedido. Tente novamente em instantes.';
    if (statusCode == 500) return 'Erro interno do servidor Kimi.';
    return 'Erro na API Kimi ($statusCode).';
  }
}
