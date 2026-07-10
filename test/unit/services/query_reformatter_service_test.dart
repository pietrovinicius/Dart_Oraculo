import 'dart:async';
import 'dart:convert';

import 'package:dart_oraculo/core/services/query_reformatter_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fake_secure_storage.dart';

void main() {
  group('QueryReformatterService', () {
    late QueryReformatterService service;
    late FakeSecureStorage fakeStorage;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      fakeStorage.store['anthropic_api_key'] = 'sk-test-key-1234567890';
    });

    MockClient _mockClient(String responseText, {int statusCode = 200}) {
      return MockClient((request) async {
        return http.Response(
          jsonEncode({
            'content': [{'type': 'text', 'text': responseText}],
          }),
          statusCode,
        );
      });
    }

    test('reformula query com filler removido', () async {
      service = QueryReformatterService(
        httpClient: _mockClient('diarreia dor abdominal'),
        storage: fakeStorage,
      );

      final result = await service.reformat('pesquisa entao diarreia e dor abdominal');
      expect(result, 'diarreia dor abdominal');
    });

    test('retorna original se query curta (≤ 3 termos)', () async {
      service = QueryReformatterService(
        httpClient: _mockClient('should not call'),
        storage: fakeStorage,
      );

      final result = await service.reformat('dor abdominal');
      expect(result, 'dor abdominal');
    });

    test('retorna original se toggle desabilitado', () async {
      fakeStorage.store['query_reformat_enabled'] = 'false';
      service = QueryReformatterService(
        httpClient: _mockClient('should not call'),
        storage: fakeStorage,
      );

      final result = await service.reformat('pesquisa entao diarreia e dor abdominal');
      expect(result, 'pesquisa entao diarreia e dor abdominal');
    });

    test('retorna original se sem API key', () async {
      fakeStorage.store.remove('anthropic_api_key');
      service = QueryReformatterService(
        httpClient: _mockClient('should not call'),
        storage: fakeStorage,
      );

      final result = await service.reformat('pesquisa entao diarreia e dor abdominal');
      expect(result, 'pesquisa entao diarreia e dor abdominal');
    });

    test('retorna original se API retorna erro', () async {
      service = QueryReformatterService(
        httpClient: _mockClient('', statusCode: 500),
        storage: fakeStorage,
      );

      final result = await service.reformat('pesquisa entao diarreia e dor abdominal');
      expect(result, 'pesquisa entao diarreia e dor abdominal');
    });

    test('retorna original se timeout (2s)', () async {
      final slowClient = MockClient((request) async {
        await Future.delayed(const Duration(seconds: 3));
        return http.Response(
          jsonEncode({'content': [{'type': 'text', 'text': 'result'}]}),
          200,
        );
      });

      service = QueryReformatterService(
        httpClient: slowClient,
        storage: fakeStorage,
      );

      final result = await service.reformat('pesquisa entao diarreia e dor abdominal');
      expect(result, 'pesquisa entao diarreia e dor abdominal');
    });

    test('cache hit — segunda chamada não bate API', () async {
      var callCount = 0;
      final countingClient = MockClient((request) async {
        callCount++;
        return http.Response(
          jsonEncode({'content': [{'type': 'text', 'text': 'reformulado'}]}),
          200,
        );
      });

      service = QueryReformatterService(
        httpClient: countingClient,
        storage: fakeStorage,
      );

      await service.reformat('pesquisa entao diarreia e dor abdominal');
      await service.reformat('pesquisa entao diarreia e dor abdominal');

      expect(callCount, 1);
    });
  });
}
