import 'package:dart_oraculo/core/theme/app_colors.dart';
import 'package:dart_oraculo/core/theme/app_theme.dart';
import 'package:dart_oraculo/features/chat/widgets/chat_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatInput focus visual', () {
    testWidgets('mostra borda laranja quando focado', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatInput(onSend: (_) {}),
          ),
        ),
      );

      // Foca o input
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Verifica que container pai tem borda laranja
      final containers = tester.widgetList<Container>(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(Container),
        ),
      );

      // Pelo menos um container deve ter borda com cor laranja
      final hasFocusBorder = containers.any((c) {
        final decoration = c.decoration;
        if (decoration is BoxDecoration && decoration.border is Border) {
          final border = decoration.border! as Border;
          return border.top.color == AppColors.accentOrange;
        }
        return false;
      });

      expect(hasFocusBorder, isTrue,
          reason: 'Input focado deve ter borda laranja');
    });
  });
}
