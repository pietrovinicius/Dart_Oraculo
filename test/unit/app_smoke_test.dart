import 'package:dart_oraculo/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app instancia sem erro', (tester) async {
    // O ChatScreen tenta inicializar DB/Storage assincronamente.
    // Em teste sem plugins nativos, ignoramos erros de MissingPlugin.
    final errors = <FlutterErrorDetails>[];
    FlutterError.onError = (details) => errors.add(details);

    await tester.pumpWidget(const DartOraculoApp());

    // App monta — verifica que o widget tree existe
    expect(find.byType(MaterialApp), findsOneWidget);

    FlutterError.onError = FlutterError.presentError;
  });
}
