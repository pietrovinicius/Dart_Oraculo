import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_oraculo/core/models/image_attachment.dart';
import 'package:dart_oraculo/core/services/ollama_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('OllamaService imagem', () {
    test('inclui campo images com base64 na mensagem user', () async {
      Map<String, dynamic>? capturedBody;

      // Mock que responde /api/tags e /api/chat
      final tagsMockClient = MockClient.streaming((request, bodyStream) async {
        if (request.url.path == '/api/tags') {
          final tagsBody = jsonEncode({
            'models': [
              {'name': 'qwen3.5:latest'}
            ]
          });
          return http.StreamedResponse(
            Stream.value(utf8.encode(tagsBody)),
            200,
          );
        }
        // /api/chat
        final body = await bodyStream.bytesToString();
        capturedBody = jsonDecode(body) as Map<String, dynamic>;
        const responseBody =
            '{"message":{"role":"assistant","content":"ok"},"done":true}\n';
        return http.StreamedResponse(
          Stream.value(utf8.encode(responseBody)),
          200,
        );
      });

      final service = OllamaService(httpClient: tagsMockClient);

      final imageBytes = Uint8List.fromList([10, 20, 30]);
      final attachment = ImageAttachment(
        bytes: imageBytes,
        mediaType: 'image/png',
      );

      await service
          .streamResponse(
            systemPrompt: 'system',
            history: [],
            question: 'descreva',
            images: [attachment],
          )
          .drain<void>();

      expect(capturedBody, isNotNull);

      final messages = capturedBody!['messages'] as List;
      final userMsg = messages.last as Map<String, dynamic>;
      expect(userMsg['role'], 'user');
      expect(userMsg['content'], 'descreva');
      expect(userMsg['images'], isNotNull);

      final imgs = userMsg['images'] as List;
      expect(imgs.length, 1);
      expect(imgs[0], base64Encode(imageBytes));
    });
  });
}
