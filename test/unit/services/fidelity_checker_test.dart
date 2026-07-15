import 'dart:convert';

import 'package:dart_oraculo/core/services/fidelity_checker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('FidelityChecker', () {
    test('retorna grounded=true quando verificador confirma', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': '{"grounded": true}'}
            ],
          }),
          200,
        );
      });

      final checker = FidelityChecker(
        headers: {
          'x-api-key': 'sk-test-123456789',
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        httpClient: mockClient,
      );

      final result = await checker.check(
        answerText: 'ADEP_V é uma view do TASY.',
        chunksContext: 'Tabela ADEP_V, colunas: ...',
        verifierModel: 'claude-opus-4-8',
      );

      expect(result.isGrounded, isTrue);
      expect(result.ungroundedClaims, isNull);
    });

    test('retorna grounded=false com claims quando verificador rejeita', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [
              {
                'type': 'text',
                'text': '{"grounded": false, "claims": ["ADEP_V foi criada em 2020"]}'
              }
            ],
          }),
          200,
        );
      });

      final checker = FidelityChecker(
        headers: {
          'x-api-key': 'sk-test-123456789',
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        httpClient: mockClient,
      );

      final result = await checker.check(
        answerText: 'ADEP_V foi criada em 2020.',
        chunksContext: 'Tabela ADEP_V, colunas: ...',
        verifierModel: 'claude-sonnet-4-6',
      );

      expect(result.isGrounded, isFalse);
      expect(result.ungroundedClaims, contains('ADEP_V foi criada em 2020'));
    });

    test(
        'retorna conservador (grounded=false) em erro HTTP 500 — nunca bypasse safety',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final checker = FidelityChecker(
        headers: {
          'x-api-key': 'sk-test-123456789',
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        httpClient: mockClient,
      );

      final result = await checker.check(
        answerText: 'qualquer coisa',
        chunksContext: 'contexto',
        verifierModel: 'claude-opus-4-8',
      );

      expect(result.isGrounded, isFalse);
      expect(result.reason, isNotNull);
    });

    test(
        'retorna conservador (grounded=false) em exceção de rede — nunca bypasse safety',
        () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network unavailable');
      });

      final checker = FidelityChecker(
        headers: {
          'x-api-key': 'sk-test-123456789',
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        httpClient: mockClient,
      );

      final result = await checker.check(
        answerText: 'qualquer coisa',
        chunksContext: 'contexto',
        verifierModel: 'claude-opus-4-8',
      );

      expect(result.isGrounded, isFalse);
      expect(result.reason, isNotNull);
    });

    test('envia cache_control ephemeral no system', () async {
      Map<String, dynamic>? capturedBody;
      final mockClient = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'content': [
              {'type': 'text', 'text': '{"grounded": true}'}
            ],
          }),
          200,
        );
      });

      final checker = FidelityChecker(
        headers: {
          'x-api-key': 'sk-test-123456789',
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        },
        httpClient: mockClient,
      );

      await checker.check(
        answerText: 'teste',
        chunksContext: 'chunks',
        verifierModel: 'claude-sonnet-4-6',
      );

      expect(capturedBody, isNotNull);
      final system = capturedBody!['system'] as List;
      expect(system.first['cache_control'], {'type': 'ephemeral'});
    });
  });
}
