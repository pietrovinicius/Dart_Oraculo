import 'package:dart_oraculo/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app instancia sem erro', (tester) async {
    await tester.pumpWidget(const DartOraculoApp());
    expect(find.text('Dart Oráculo'), findsOneWidget);
  });
}
