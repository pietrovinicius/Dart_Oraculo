import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'logger_service.dart';

/// Resultado da checagem de fidelidade.
class FidelityCheckResult {
  const FidelityCheckResult({
    required this.isGrounded,
    this.ungroundedClaims,
    this.reason,
  });

  final bool isGrounded;
  final List<String>? ungroundedClaims;

  /// Explica o resultado — útil quando o check falha/indisponível para o caller
  /// decidir entre bloquear promoção ou pedir confirmação ao usuário.
  final String? reason;
}

/// Verifica se uma resposta está fundamentada nos chunks usados.
/// Usa motor Anthropic cruzado (Sonnet verifica Opus, vice-versa).
class FidelityChecker {
  FidelityChecker({
    required Map<String, String> headers,
    http.Client? httpClient,
  })  : _headers = headers,
        _httpClient = httpClient ?? http.Client();

  static const _tag = 'FidelityChecker';
  final Map<String, String> _headers;
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
          ..._headers,
          'anthropic-beta': 'prompt-caching-2024-07-31',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        LoggerService.instance.error(_tag,
            'Verificador retornou ${response.statusCode}: ${response.body}');
        // CONSERVADOR: HTTP não-200 = não verificável. Nunca bypasse safety check.
        return const FidelityCheckResult(
          isGrounded: false,
          reason: 'Verificador retornou status HTTP não-ok.',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['content'] as List?;
      if (content == null || content.isEmpty) {
        return const FidelityCheckResult(
          isGrounded: false,
          reason: 'Resposta do verificador vazia.',
        );
      }

      final text = content.first['text'] as String? ?? '';
      LoggerService.instance.info(_tag, 'Resposta verificador: $text');

      // Parse JSON da resposta
      final resultJson = _extractJson(text);
      if (resultJson == null) {
        return const FidelityCheckResult(
          isGrounded: false,
          reason: 'Resposta do verificador não pôde ser interpretada.',
        );
      }

      final grounded = resultJson['grounded'] as bool? ?? true;
      final claims = resultJson['claims'] as List?;

      return FidelityCheckResult(
        isGrounded: grounded,
        ungroundedClaims: claims?.map((c) => c.toString()).toList(),
      );
    } catch (e) {
      LoggerService.instance.error(_tag, 'Erro na checagem de fidelidade', e);
      // CONSERVADOR: em caso de erro, marca como NÃO fundamentado.
      // Nunca bypasse safety check — melhor falso negativo que falso positivo.
      return const FidelityCheckResult(
        isGrounded: false,
        reason: 'Verificação de fidelidade indisponível. Resposta não verificada.',
      );
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
