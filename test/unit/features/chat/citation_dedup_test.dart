import 'package:dart_oraculo/features/chat/utils/citation_dedup.dart';
import 'package:dart_oraculo/features/chat/widgets/citation_strip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dedupeCitations', () {
    test('removes duplicates by filename+page+sourceType', () {
      final a = CitationData(filename: 'doc.pdf', page: 1, sourceType: 'document');
      final b = CitationData(filename: 'doc.pdf', page: 1, sourceType: 'document');
      final c = CitationData(filename: 'doc.pdf', page: 2, sourceType: 'document');

      final result = dedupeCitations([a, b, c]);

      expect(result, hasLength(2));
      expect(result[0].page, 1);
      expect(result[1].page, 2);
    });

    test('returns empty list when input is empty', () {
      expect(dedupeCitations([]), isEmpty);
    });

    test('preserves order of first occurrence', () {
      final a = CitationData(filename: 'a.pdf', page: 1);
      final b = CitationData(filename: 'b.pdf', page: 1);
      final c = CitationData(filename: 'a.pdf', page: 1);

      final result = dedupeCitations([a, b, c]);

      expect(result, hasLength(2));
      expect(result[0].filename, 'a.pdf');
      expect(result[1].filename, 'b.pdf');
    });

    test(
      'returns ORIGINAL input unchanged when dedup logic fails (no silent empty)',
      () {
        // Bug original: catch (_) { return []; } — usuário perdia todas as
        // citações se dedup falhasse. Contrato esperado: retornar input
        // intacto para que o usuário ainda veja as fontes brutas.
        final input = [
          CitationData(filename: 'doc1.pdf', page: 1),
          CitationData(filename: 'doc2.pdf', page: 2),
          CitationData(filename: 'doc3.pdf', page: 3),
        ];

        // Mesmo em cenário adverso (citation malformada que dispara exceção
        // no loop interno), o fallback deve preservar os dados.
        final result = dedupeCitationsWithFallback(input, () {
          throw StateError('simulated dedup failure');
        });

        expect(result, hasLength(3));
        expect(result.map((c) => c.filename).toList(),
            ['doc1.pdf', 'doc2.pdf', 'doc3.pdf']);
      },
    );
  });
}