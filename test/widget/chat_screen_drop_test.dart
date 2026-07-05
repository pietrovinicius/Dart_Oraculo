import 'package:dart_oraculo/features/chat/chat_screen.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatScreen Drag&Drop', () {
    testWidgets('contém DropTarget widget na árvore', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ChatScreen()),
      );
      await tester.pumpAndSettle();

      // DropTarget deve existir na árvore de widgets
      expect(find.byType(DropTarget), findsOneWidget);
    });
  });
}
