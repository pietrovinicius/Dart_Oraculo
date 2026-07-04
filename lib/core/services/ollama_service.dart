import 'dart:convert';

import 'package:http/http.dart' as http;

import 'generation_service.dart';
import 'logger_service.dart';

/// Exceção para erros do Ollama.
class OllamaException implements Exception {
  const OllamaException(this.message);
  final String message;

  @override
  String toString() => 'OllamaException: $message';
}

/// Motor de geração local via Ollama (http://localhost:11434).
class OllamaService implements GenerationService {
  OllamaService({
    this.model = 'qwen3.5:latest',
    this.baseUrl = 'http://localhost:11434',
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client() {
    // Rejeita modelos :cloud — execução remota, não local
    if (model.endsWith(':cloud')) {
      throw OllamaException(
        'Modelo "$model" usa tag :cloud (execução remota). '
        'O Dart Oráculo só suporta modelos locais via Ollama.',
      );
    }
  }

  static const _tag = 'OllamaService';
  final String model;
  final String baseUrl;
  final http.Client _httpClient;

  @override
  @override
  String get modelDisplayName => 'Qwen (Local)';

  @override
  int get maxContextCharsPerChunk => 4000;

  /// Verifica se Ollama está rodando e o modelo disponível.
  Future<void> _checkAvailability() async {
    try {
      final response = await _httpClient
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw OllamaException(
          'Ollama não está respondendo (status ${response.statusCode}). '
          'Abra o aplicativo Ollama ou rode "ollama serve" no terminal.',
        );
      }

      // Verifica se o modelo está disponível
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final models = (body['models'] as List?) ?? [];
      final available = models.any((m) {
        final name = (m is Map) ? m['name']?.toString() ?? '' : '';
        return name == model || name.startsWith(model.split(':').first);
      });

      if (!available) {
        throw OllamaException(
          'Modelo "$model" não encontrado. '
          'Rode "ollama pull $model" no terminal para baixá-lo.',
        );
      }
    } catch (e) {
      if (e is OllamaException) rethrow;
      throw const OllamaException(
        'Ollama não está rodando ou o modelo Qwen não foi baixado nesta máquina. '
        'Abra o aplicativo Ollama ou rode "ollama serve" no terminal.',
      );
    }
  }

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String question,
  }) async* {
    LoggerService.instance.info(_tag, 'streamResponse(model=$model)');

    // Verifica disponibilidade antes de cada chamada
    await _checkAvailability();

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': question},
    ];

    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'stream': true,
    });

    LoggerService.instance.info(_tag, 'POST $baseUrl/api/chat');

    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/api/chat'));
      request.headers['content-type'] = 'application/json';
      request.body = body;

      final streamedResponse = await _httpClient.send(request)
          .timeout(const Duration(minutes: 10));

      if (streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        LoggerService.instance.error(_tag, 'Ollama error: $responseBody');
        throw OllamaException('Erro do Ollama (${streamedResponse.statusCode})');
      }

      // Ollama streaming: objetos JSON delimitados por \n
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty);
        for (final line in lines) {
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final message = json['message'] as Map<String, dynamic>?;
            final content = message?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
            // Verifica fim do stream
            if (json['done'] == true) {
              LoggerService.instance.info(_tag, 'streamResponse() completo');
              return;
            }
          } on FormatException {
            // Ignora linhas que não são JSON válido
          }
        }
      }
    } catch (e) {
      if (e is OllamaException) rethrow;
      LoggerService.instance.error(_tag, 'Erro de conexão Ollama', e);
      throw OllamaException('Erro de conexão com Ollama: $e');
    }
  }
}
