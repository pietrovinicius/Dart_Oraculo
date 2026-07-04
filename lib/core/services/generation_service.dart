/// Interface abstrata para motores de geração de texto.
/// Implementada por AnthropicService e OllamaService.
abstract class GenerationService {
  /// Envia mensagem e retorna stream de tokens da resposta.
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String question,
  });

  /// Identificador do modelo para exibição na UI.
  String get modelDisplayName;
}
