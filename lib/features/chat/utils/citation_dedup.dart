import '../../../core/services/logger_service.dart';
import '../widgets/citation_strip.dart';

/// Chave de deduplicação de uma citação: filename + page + sourceType.
String _citationKey(CitationData c) =>
    '${c.filename}_${c.page}_${c.sourceType}';

/// Deduplica uma lista de [CitationData] preservando a ordem da primeira
/// ocorrência. Identidade = filename + page + sourceType.
///
/// Em caso de falha na lógica de dedup, retorna a lista original intacta
/// (NUNCA `[]`) — o usuário deve ver as fontes brutas em vez de um falso
/// "nenhuma fonte encontrada".
List<CitationData> dedupeCitations(List<CitationData> citations) {
  try {
    final seen = <String>{};
    final deduped = <CitationData>[];
    for (final c in citations) {
      final key = _citationKey(c);
      if (!seen.contains(key)) {
        seen.add(key);
        deduped.add(c);
      }
    }
    return deduped;
  } catch (e, stack) {
    LoggerService.instance.error(
      'citation_dedup',
      'Falha ao deduplicar citações — retornando lista original (sem dedup)',
      e,
      stack,
    );
    // NEVER return [] on failure — retorna input para preservar fontes.
    return citations;
  }
}

/// Variante testável que recebe a função de dedup como parâmetro. Usada
/// em testes para simular falhas sem precisar mockar o estado interno.
List<CitationData> dedupeCitationsWithFallback(
  List<CitationData> citations,
  List<CitationData> Function() dedupFn,
) {
  try {
    return dedupFn();
  } catch (e) {
    return citations;
  }
}