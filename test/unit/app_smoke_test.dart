import 'package:flutter_test/flutter_test.dart';
import 'package:dart_oraculo/app.dart';

void main() {
  testWidgets('app instancia sem erro', (tester) async {
    await tester.pumpWidget(const DartOraculoApp());
    expect(find.text('Dart Oráculo'), findsOneWidget);
  });
}
