import '../models/image_attachment.dart';

/// Interface abstrata para motores de geração de texto.
/// Implementada por AnthropicService e OllamaService.
abstract class GenerationService {
  /// Envia mensagem e retorna stream de tokens da resposta.
  /// [images] — lista opcional de imagens anexadas à pergunta.
  /// [allowGeneralKnowledge] — quando true, prompt permite fallback de conhecimento geral.
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String question,
    List<ImageAttachment>? images,
    bool allowGeneralKnowledge = false,
  });

  /// Identificador do modelo para exibição na UI.
  String get modelDisplayName;

  /// Limite de caracteres por chunk individual no contexto do prompt.
  /// Motores em nuvem (Anthropic): 20000 — prioriza completude de resposta.
  /// Motor local (Ollama): 4000 — prioriza velocidade percebida.
  int get maxContextCharsPerChunk;
}
