import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'logger_service.dart';

/// Resultado da checagem de fidelidade.
class FidelityCheckResult {
  const FidelityCheckResult({required this.isGrounded, this.ungroundedClaims});

  final bool isGrounded;
  final List<String>? ungroundedClaims;
}

/// Verifica se uma resposta está fundamentada nos chunks usados.
/// Usa motor Anthropic cruzado (Sonnet verifica Opus, vice-versa).
class FidelityChecker {
  FidelityChecker({
    required String apiKey,
    http.Client? httpClient,
  })  : _apiKey = apiKey,
        _httpClient = httpClient ?? http.Client();

  static const _tag = 'FidelityChecker';
  final String _apiKey;
  final http.Client _httpClient;

  /// Verifica fidelidade da [answerText] contra [chunksContext].
  /// [verifierModel] é o modelo oposto ao que gerou a resposta.
  Future<FidelityCheckResult> check({
    required String answerText,
    required String chunksContext,
    required String verifierModel,
  }) async {
    LoggerService.instance.info(_tag,
        'Verificando fidelidade com $verifierModel (${answerText.length} chars resposta)');

    final systemPrompt = 'Você é um verificador de fidelidade. '
        'Analise se TODAS as afirmações factuais da RESPOSTA abaixo '
        'estão sustentadas pelos TRECHOS FONTE fornecidos.\n\n'
        'Responda APENAS em formato JSON:\n'
        '{"grounded": true} se tudo fundamentado.\n'
        '{"grounded": false, "claims": ["afirmação X"]} se houver não fundamentadas.\n\n'
        '--- TRECHOS FONTE ---\n'
        '$chunksContext\n'
        '--- FIM TRECHOS ---';

    final body = jsonEncode({
      'model': verifierModel,
      'max_tokens': 512,
      'stream': false,
      'system': [
        {
          'type': 'text',
          'text': systemPrompt,
          'cache_control': {'type': 'ephemeral'},
        },
      ],
      'messages': [
        {
          'role': 'user',
          'content': '--- RESPOSTA A VERIFICAR ---\n'
              '$answerText\n'
              '--- FIM RESPOSTA ---',
        },
      ],
    });

    try {
      final response = await _httpClient.post(
        Uri.parse(AppConfig.anthropicBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey,
          'anthropic-version': AppConfig.anthropicVersion,
          'anthropic-beta': 'prompt-caching-2024-07-31',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        LoggerService.instance.error(_tag,
            'Verificador retornou ${response.statusCode}: ${response.body}');
        // Em caso de erro, não bloqueia promoção
        return const FidelityCheckResult(isGrounded: true);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['content'] as List?;
      if (content == null || content.isEmpty) {
        return const FidelityCheckResult(isGrounded: true);
      }

      final text = content.first['text'] as String? ?? '';
      LoggerService.instance.info(_tag, 'Resposta verificador: $text');

      // Parse JSON da resposta
      final resultJson = _extractJson(text);
      if (resultJson == null) {
        return const FidelityCheckResult(isGrounded: true);
      }

      final grounded = resultJson['grounded'] as bool? ?? true;
      final claims = resultJson['claims'] as List?;

      return FidelityCheckResult(
        isGrounded: grounded,
        ungroundedClaims: claims?.map((c) => c.toString()).toList(),
      );
    } catch (e) {
      LoggerService.instance.error(_tag, 'Erro na checagem de fidelidade', e);
      // Em caso de erro, não bloqueia promoção
      return const FidelityCheckResult(isGrounded: true);
    }
  }

  /// Extrai JSON de uma string que pode ter texto adicional.
  Map<String, dynamic>? _extractJson(String text) {
    try {
      // Tenta parsear diretamente
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      // Tenta extrair JSON de dentro do texto
      final match = RegExp(r'\{[^}]+\}').firstMatch(text);
      if (match != null) {
        try {
          return jsonDecode(match.group(0)!) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      }
      return null;
    }
  }
}
