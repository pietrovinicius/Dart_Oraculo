import 'dart:convert';

import 'package:dart_oraculo/core/services/ollama_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OllamaService', () {
    test('rejeita modelo com sufixo :cloud', () {
      expect(
        () => OllamaService(model: 'qwen3.5:cloud'),
        throwsA(isA<OllamaException>()),
      );
    });

    test('aceita modelo sem :cloud', () {
      final service = OllamaService(
        model: 'qwen3.5:latest',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      expect(service.model, equals('qwen3.5:latest'));
      expect(service.modelDisplayName, equals('Qwen (Local)'));
    });

    test('lança OllamaException quando serviço não responde', () async {
      final service = OllamaService(
        model: 'qwen3.5:latest',
        httpClient: MockClient((_) async => throw Exception('Connection refused')),
      );

      expect(
        () => service.streamResponse(
          systemPrompt: 'test',
          history: [],
          question: 'oi',
        ).toList(),
        throwsA(isA<OllamaException>()),
      );
    });

    test('lança OllamaException quando modelo não está disponível', () async {
      final service = OllamaService(
        model: 'modelo-inexistente:latest',
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/tags') {
            return http.Response(
              jsonEncode({
                'models': [
                  {'name': 'qwen3.5:latest'},
                ]
              }),
              200,
            );
          }
          return http.Response('', 200);
        }),
      );

      expect(
        () => service.streamResponse(
          systemPrompt: 'test',
          history: [],
          question: 'oi',
        ).toList(),
        throwsA(isA<OllamaException>()),
      );
    });

    test('parseia streaming corretamente', () async {
      final service = OllamaService(
        model: 'qwen3.5:latest',
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/tags') {
            return http.Response(
              jsonEncode({
                'models': [{'name': 'qwen3.5:latest'}],
              }),
              200,
            );
          }
          // /api/chat — simula streaming com objetos JSON por linha (ASCII-safe)
          final streamBody = [
            jsonEncode({'message': {'role': 'assistant', 'content': 'Hello'}, 'done': false}),
            jsonEncode({'message': {'role': 'assistant', 'content': ' world'}, 'done': false}),
            jsonEncode({'message': {'role': 'assistant', 'content': ''}, 'done': true}),
          ].join('\n');
          return http.Response(streamBody, 200);
        }),
      );

      final tokens = <String>[];
      await for (final token in service.streamResponse(
        systemPrompt: 'You are an assistant.',
        history: [],
        question: 'Hi',
      )) {
        tokens.add(token);
      }

      expect(tokens, equals(['Hello', ' world']));
    });
  });
}
