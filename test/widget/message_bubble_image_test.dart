import 'dart:io';
import 'dart:typed_data';

import 'package:dart_oraculo/core/theme/app_theme.dart';
import 'package:dart_oraculo/features/chat/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageBubble imagem', () {
    testWidgets('exibe miniatura quando imagePath presente', (tester) async {
      // Cria arquivo temporário com PNG mínimo
      final tempDir = Directory.systemTemp.createTempSync('bubble_test_');
      final imageFile = File('${tempDir.path}/test_image.png');
      imageFile.writeAsBytesSync(_minimalPng());

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(
                content: 'O que é isto?',
                isUser: true,
                timestamp: DateTime.now(),
                imagePath: imageFile.path,
              ),
            ),
          ),
        ),
      );

      // Deve haver um Image widget (a miniatura)
      expect(find.byType(Image), findsOneWidget);
      // Texto também presente
      expect(find.text('O que é isto?'), findsOneWidget);

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });

    testWidgets('não exibe imagem quando imagePath é null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MessageBubble(
                content: 'Pergunta sem imagem',
                isUser: true,
                timestamp: DateTime.now(),
              ),
            ),
          ),
        ),
      );

      // Não deve haver Image widget
      expect(find.byType(Image), findsNothing);
      expect(find.text('Pergunta sem imagem'), findsOneWidget);
    });
  });
}

Uint8List _minimalPng() {
  return Uint8List.fromList([
    137, 80, 78, 71, 13, 10, 26, 10,
    0, 0, 0, 13, 73, 72, 68, 82,
    0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0,
    31, 21, 196, 137,
    0, 0, 0, 10, 73, 68, 65, 84,
    120, 156, 98, 0, 0, 0, 2, 0, 1,
    226, 33, 188, 51,
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]);
}
