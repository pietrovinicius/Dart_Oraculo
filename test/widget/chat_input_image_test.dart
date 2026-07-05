import 'dart:typed_data';

import 'package:dart_oraculo/core/services/clipboard_image_service.dart';
import 'package:dart_oraculo/core/theme/app_theme.dart';
import 'package:dart_oraculo/features/chat/widgets/chat_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mock do ClipboardImageService para testes de widget.
class FakeClipboardImageService extends ClipboardImageService {
  Uint8List? imageToReturn;

  @override
  Future<Uint8List?> getImage() async => imageToReturn;
}

void main() {
  group('ChatInput Cmd+V', () {
    testWidgets('com imagem no clipboard → mostra preview de anexo',
        (tester) async {
      final fakeClipboard = FakeClipboardImageService();
      // PNG mínimo válido (1x1 pixel)
      fakeClipboard.imageToReturn = _minimalPng();

      String? sentText;
      Uint8List? sentImage;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatInput(
              onSend: (text) => sentText = text,
              onSendWithImage: (text, bytes, _) {
                sentText = text;
                sentImage = bytes;
              },
              clipboardImageService: fakeClipboard,
            ),
          ),
        ),
      );

      // Foca o input
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Simula Cmd+V
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      // Preview deve estar visível (Image.memory)
      expect(find.byType(Image), findsOneWidget);
      // Botão de remover (close) deve estar presente
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('sem imagem no clipboard → texto cola normalmente (sem anexo)',
        (tester) async {
      final fakeClipboard = FakeClipboardImageService();
      fakeClipboard.imageToReturn = null; // Sem imagem

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatInput(
              onSend: (_) {},
              clipboardImageService: fakeClipboard,
            ),
          ),
        ),
      );

      // Foca o input
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Simula Cmd+V (sem imagem no clipboard)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      // NÃO deve haver preview de imagem
      expect(find.byType(Image), findsNothing);
      // O campo de texto deve permanecer funcional (sem anexo criado)
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}

/// Gera um PNG válido de 1x1 pixel (transparente).
Uint8List _minimalPng() {
  return Uint8List.fromList([
    // PNG signature
    137, 80, 78, 71, 13, 10, 26, 10,
    // IHDR chunk
    0, 0, 0, 13, 73, 72, 68, 82,
    0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0,
    31, 21, 196, 137,
    // IDAT chunk
    0, 0, 0, 10, 73, 68, 65, 84,
    120, 156, 98, 0, 0, 0, 2, 0, 1,
    226, 33, 188, 51,
    // IEND chunk
    0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
  ]);
}
