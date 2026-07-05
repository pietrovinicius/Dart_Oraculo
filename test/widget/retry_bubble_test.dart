import 'package:dart_oraculo/core/theme/app_theme.dart';
import 'package:dart_oraculo/features/chat/widgets/retry_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetryBubble', () {
    testWidgets('mostra mensagem de erro e botão tentar novamente', (tester) async {
      var retryCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: RetryBubble(
              onRetry: () => retryCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Falha ao gerar resposta'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();

      expect(retryCalled, isTrue);
    });
  });
}
