import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/image_attachment.dart';
import 'generation_service.dart';
import 'logger_service.dart';

/// Exceção para erros da API Anthropic.
class AnthropicException implements Exception {
  const AnthropicException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => 'AnthropicException($statusCode): $message';
}

/// Cliente HTTP direto para api.anthropic.com/v1/messages.
class AnthropicService implements GenerationService {
  AnthropicService({
    required String apiKey,
    http.Client? httpClient,
    this.model = 'claude-sonnet-4-6',
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client();

  final String model;

  static const _tag = 'AnthropicAPI';
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
    List<ImageAttachment>? images,
  }) {
    final systemPrompt = 'Você é o Dart Oráculo, um assistente de conhecimento pessoal. '
        'Responda com base exclusivamente no contexto fornecido abaixo. '
        'Se a informação não estiver no contexto, diga que não encontrou nos documentos.\n\n'
        '--- CONTEXTO ---\n$context\n--- FIM DO CONTEXTO ---';

    // Monta content da mensagem do user (com ou sem imagem)
    final dynamic userContent;
    if (images != null && images.isNotEmpty) {
      final contentBlocks = <Map<String, dynamic>>[];
      for (final img in images) {
        contentBlocks.add({
          'type': 'image',
          'source': {
            'type': 'base64',
            'media_type': img.mediaType,
            'data': base64Encode(img.bytes),
          },
        });
      }
      contentBlocks.add({'type': 'text', 'text': userMessage});
      userContent = contentBlocks;
    } else {
      userContent = userMessage;
    }

    final messages = <Map<String, dynamic>>[
      ...history,
      {'role': 'user', 'content': userContent},
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
      // Log do modelo usado (aparece no message_start)
      if (json['type'] == 'message_start') {
        final message = json['message'] as Map<String, dynamic>?;
        if (message != null) {
          final modelUsed = message['model'] as String?;
          final usage = message['usage'] as Map<String, dynamic>?;
          LoggerService.instance.info(
            _tag,
            'message_start → model=$modelUsed, input_tokens=${usage?['input_tokens']}',
          );
        }
      }
      // Log de uso final (message_delta com stop_reason)
      if (json['type'] == 'message_delta') {
        final delta = json['delta'] as Map<String, dynamic>?;
        final usage = json['usage'] as Map<String, dynamic>?;
        LoggerService.instance.info(
          _tag,
          'message_delta → stop_reason=${delta?['stop_reason']}, output_tokens=${usage?['output_tokens']}',
        );
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
    List<ImageAttachment>? images,
  }) async* {
    LoggerService.instance.info(_tag, 'sendMessage() → model=$model, apiKey=${_apiKey.length > 10 ? "${_apiKey.substring(0, 10)}..." : "[EMPTY]"}');

    if (_apiKey.isEmpty) {
      LoggerService.instance.error(_tag, 'API key está vazia! Configure em Configurações.');
      throw const AnthropicException('API key não configurada', 0);
    }

    final body = buildRequestBody(
      userMessage: userMessage,
      context: context,
      history: history,
      model: model,
      images: images,
    );

    LoggerService.instance.info(_tag, 'POST ${AppConfig.anthropicBaseUrl}');

    try {
      final response = await _httpClient.post(
        Uri.parse(AppConfig.anthropicBaseUrl),
        headers: buildHeaders(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 90));

      LoggerService.instance.info(_tag, 'response.statusCode=${response.statusCode}');

      if (response.statusCode != 200) {
        String errorMessage;
        try {
          final errorJson = jsonDecode(response.body) as Map<String, dynamic>;
          final error = errorJson['error'] as Map<String, dynamic>?;
          errorMessage = error?['message'] as String? ?? response.body;
        } on FormatException {
          errorMessage = response.body;
        }
        LoggerService.instance.error(_tag, 'API error: $errorMessage (status=${response.statusCode})');
        throw AnthropicException(errorMessage, response.statusCode);
      }

      final lines = response.body.split('\n');
      for (final line in lines) {
        final text = parseStreamEvent(line);
        if (text != null) {
          yield text;
        }
      }

      LoggerService.instance.info(_tag, 'sendMessage() completo com sucesso');
    } catch (e, stack) {
      if (e is AnthropicException) rethrow;
      LoggerService.instance.error(_tag, 'Erro de rede/conexão', e, stack);
      throw AnthropicException('Erro de conexão: $e', 0);
    }
  }

  // --- GenerationService interface ---

  @override
  String get modelDisplayName => model;

  @override
  int get maxContextCharsPerChunk => 20000;

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String question,
    List<ImageAttachment>? images,
  }) {
    return sendMessage(
      userMessage: question,
      context: systemPrompt,
      history: history,
      model: model,
      images: images,
    );
  }
}
