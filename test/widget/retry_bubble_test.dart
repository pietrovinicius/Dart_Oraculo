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

    testWidgets('exibe errorMessage detalhada quando fornecida', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: RetryBubble(
              onRetry: () {},
              errorMessage: 'Rate limit exceeded: too many requests',
            ),
          ),
        ),
      );

      expect(find.text('Falha ao gerar resposta'), findsOneWidget);
      expect(find.text('Rate limit exceeded: too many requests'), findsOneWidget);
    });

    testWidgets('trunca errorMessage longa a 120 caracteres', (tester) async {
      final longError = 'A' * 200;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: RetryBubble(
              onRetry: () {},
              errorMessage: longError,
            ),
          ),
        ),
      );

      // Mensagem completa não deve aparecer
      expect(find.text(longError), findsNothing);
      // Versão truncada com "…" deve aparecer
      expect(find.text('${'A' * 120}…'), findsOneWidget);
    });

    testWidgets('não exibe subtitle quando errorMessage é null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: RetryBubble(
              onRetry: () {},
              errorMessage: null,
            ),
          ),
        ),
      );

      // Apenas o título principal
      expect(find.text('Falha ao gerar resposta'), findsOneWidget);
      // Nenhum Text widget extra além dos fixos
      final textWidgets = find.byType(Text);
      // Título + "Tentar novamente" = 2 textos
      expect(textWidgets, findsNWidgets(2));
    });
  });
}
