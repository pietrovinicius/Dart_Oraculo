import 'dart:convert';

import 'package:dart_oraculo/core/config/app_config.dart';
import 'package:dart_oraculo/core/services/anthropic_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AnthropicService', () {
    test('buildRequestBody monta estrutura correta', () {
      final service = AnthropicService(
        apiKey: 'sk-test-key',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      final body = service.buildRequestBody(
        userMessage: 'O que é Flutter?',
        context: 'Flutter é um framework de UI.',
        history: [],
        model: AppConfig.modelSonnet,
      );

      expect(body['model'], equals(AppConfig.modelSonnet));
      expect(body['max_tokens'], isA<int>());
      expect(body['stream'], isTrue);

      final messages = body['messages'] as List;
      expect(messages, isNotEmpty);

      // Última mensagem deve ser do user
      final lastMsg = messages.last as Map<String, dynamic>;
      expect(lastMsg['role'], equals('user'));
      expect(lastMsg['content'], contains('O que é Flutter?'));
    });

    test('buildRequestBody inclui system prompt com contexto', () {
      final service = AnthropicService(
        apiKey: 'sk-test-key',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      final body = service.buildRequestBody(
        userMessage: 'Pergunta',
        context: 'Contexto dos documentos relevantes aqui.',
        history: [],
        model: AppConfig.modelSonnet,
      );

      final system = body['system'] as String;
      expect(system, contains('Contexto dos documentos relevantes aqui.'));
    });

    test('buildRequestBody inclui histórico de mensagens', () {
      final service = AnthropicService(
        apiKey: 'sk-test-key',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      final history = [
        {'role': 'user', 'content': 'Primeira pergunta'},
        {'role': 'assistant', 'content': 'Primeira resposta'},
      ];

      final body = service.buildRequestBody(
        userMessage: 'Segunda pergunta',
        context: 'Contexto',
        history: history,
        model: AppConfig.modelOpus,
      );

      final messages = body['messages'] as List;
      // history (2) + user message (1) = 3
      expect(messages, hasLength(3));
      expect((messages[0] as Map)['content'], equals('Primeira pergunta'));
      expect((messages[1] as Map)['content'], equals('Primeira resposta'));
    });

    test('parseStreamEvent extrai texto de content_block_delta', () {
      final service = AnthropicService(
        apiKey: 'sk-test-key',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      final event = 'data: ${jsonEncode({
        'type': 'content_block_delta',
        'delta': {'type': 'text_delta', 'text': 'Hello'}
      })}';

      final text = service.parseStreamEvent(event);
      expect(text, equals('Hello'));
    });

    test('parseStreamEvent retorna null para eventos não-text', () {
      final service = AnthropicService(
        apiKey: 'sk-test-key',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      final event = 'data: ${jsonEncode({
        'type': 'message_start',
        'message': {'id': 'msg_123'}
      })}';

      expect(service.parseStreamEvent(event), isNull);
    });

    test('parseStreamEvent retorna null para linhas vazias', () {
      final service = AnthropicService(
        apiKey: 'sk-test-key',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      expect(service.parseStreamEvent(''), isNull);
      expect(service.parseStreamEvent('event: message_start'), isNull);
      expect(service.parseStreamEvent('data: [DONE]'), isNull);
    });

    test('headers contém api key e version', () {
      final service = AnthropicService(
        apiKey: 'sk-ant-my-key',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );

      final headers = service.buildHeaders();

      expect(headers['x-api-key'], equals('sk-ant-my-key'));
      expect(headers['anthropic-version'], equals(AppConfig.anthropicVersion));
      expect(headers['content-type'], equals('application/json'));
    });

    test('sendMessage faz POST e retorna stream de texto', () async {
      final responseBody = [
        'event: message_start\n',
        'data: {"type":"message_start","message":{"id":"msg_1"}}\n\n',
        'event: content_block_delta\n',
        'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Olá"}}\n\n',
        'event: content_block_delta\n',
        'data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" mundo"}}\n\n',
        'event: message_stop\n',
        'data: {"type":"message_stop"}\n\n',
      ].join();

      final service = AnthropicService(
        apiKey: 'sk-test',
        httpClient: MockClient((request) async {
          expect(request.method, equals('POST'));
          expect(request.url.toString(), equals(AppConfig.anthropicBaseUrl));
          return http.Response(responseBody, 200);
        }),
      );

      final chunks = <String>[];
      await for (final chunk in service.sendMessage(
        userMessage: 'Oi',
        context: 'Contexto',
        history: [],
        model: AppConfig.modelSonnet,
      )) {
        chunks.add(chunk);
      }

      expect(chunks, equals(['Olá', ' mundo']));
    });

    test('sendMessage lança exceção em erro HTTP', () async {
      final service = AnthropicService(
        apiKey: 'sk-test',
        httpClient: MockClient((_) async => http.Response(
          '{"error":{"message":"Invalid API key"}}',
          401,
        )),
      );

      expect(
        () => service.sendMessage(
          userMessage: 'Oi',
          context: 'Contexto',
          history: [],
          model: AppConfig.modelSonnet,
        ).toList(),
        throwsA(isA<AnthropicException>()),
      );
    });
  });
}
