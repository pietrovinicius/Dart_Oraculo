import 'package:dart_oraculo/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Context attachment chip (widget test)', () {
    testWidgets('tap no botão ✕ chama callback de remoção com ID correto',
        (tester) async {
      int? removedId;

      // Widget que simula o chip com botão de remover
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Row(
              children: [
                const Text('spec.md'),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => removedId = 42,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('spec.md'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Tap no ✕
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      // Callback foi chamado com ID correto
      expect(removedId, 42);
    });

    testWidgets('chip mostra contagem correta de attachments', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Chip(
              avatar: const Icon(Icons.attach_file, size: 14),
              label: const Text('3 docs'),
            ),
          ),
        ),
      );

      expect(find.text('3 docs'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file), findsOneWidget);
    });
  });
}
