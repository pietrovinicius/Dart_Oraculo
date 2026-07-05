import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_oraculo/core/models/image_attachment.dart';
import 'package:dart_oraculo/core/services/anthropic_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnthropicService imagem', () {
    test('buildRequestBody monta content blocks de imagem antes do texto', () {
      final service = AnthropicService(
        apiKey: 'sk-test-key-123456',
        httpClient: null,
      );

      final imageBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final attachment = ImageAttachment(
        bytes: imageBytes,
        mediaType: 'image/png',
      );

      final body = service.buildRequestBody(
        userMessage: 'O que é isto?',
        context: 'contexto teste',
        history: [],
        model: 'claude-sonnet-4-6',
        images: [attachment],
      );

      final messages = body['messages'] as List;
      expect(messages.length, 1);

      final userMsg = messages[0] as Map<String, dynamic>;
      expect(userMsg['role'], 'user');

      // content deve ser lista de blocks
      final content = userMsg['content'] as List;
      expect(content.length, 2);

      // Primeiro block: imagem
      final imgBlock = content[0] as Map<String, dynamic>;
      expect(imgBlock['type'], 'image');
      expect(imgBlock['source']['type'], 'base64');
      expect(imgBlock['source']['media_type'], 'image/png');
      expect(imgBlock['source']['data'], base64Encode(imageBytes));

      // Segundo block: texto
      final txtBlock = content[1] as Map<String, dynamic>;
      expect(txtBlock['type'], 'text');
      expect(txtBlock['text'], 'O que é isto?');
    });

    test('buildRequestBody sem imagem mantém content como string', () {
      final service = AnthropicService(
        apiKey: 'sk-test-key-123456',
        httpClient: null,
      );

      final body = service.buildRequestBody(
        userMessage: 'Pergunta simples',
        context: 'contexto',
        history: [],
        model: 'claude-sonnet-4-6',
      );

      final messages = body['messages'] as List;
      final userMsg = messages[0] as Map<String, dynamic>;
      expect(userMsg['content'], 'Pergunta simples');
    });
  });
}
