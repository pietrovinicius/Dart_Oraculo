import 'package:dart_oraculo/core/services/error_feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorFeedbackService', () {
    testWidgets('showError displays SnackBar with error message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ErrorFeedbackService.showError(
                    context,
                    'Test Error',
                    'Error details',
                  ),
                  child: const Text('Show Error'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Test Error: Error details'), findsOneWidget);
    });

    testWidgets('showCriticalError displays AlertDialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ErrorFeedbackService.showCriticalError(
                    context,
                    'Critical issue',
                  ),
                  child: const Text('Show Critical'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Erro Crítico'), findsOneWidget);
    });
  });
}
