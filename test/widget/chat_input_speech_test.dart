import 'package:dart_oraculo/core/services/speech_service.dart';
import 'package:dart_oraculo/core/theme/app_theme.dart';
import 'package:dart_oraculo/features/chat/widgets/chat_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake SpeechService para widget tests.
class FakeSpeechService extends SpeechService {
  final bool shouldBeAvailable;
  bool _listening = false;
  void Function(String text, bool isFinal)? _onResult;

  FakeSpeechService({this.shouldBeAvailable = true}) : super(speechToText: null);

  @override
  bool get isListening => _listening;

  @override
  Future<bool> initialize() async => shouldBeAvailable;

  @override
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    String? localeId,
  }) async {
    if (!shouldBeAvailable) return;
    _listening = true;
    _onResult = onResult;
  }

  @override
  Future<void> stopListening() async {
    _listening = false;
  }

  void simulateResult(String text, {bool isFinal = false}) {
    _onResult?.call(text, isFinal);
  }
}

void main() {
  group('ChatInput ditado por voz', () {
    testWidgets('botão mic inicia escuta e popula campo com resultado',
        (tester) async {
      final fakeSpeech = FakeSpeechService(shouldBeAvailable: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatInput(
              onSend: (_) {},
              speechService: fakeSpeech,
            ),
          ),
        ),
      );

      // Botão mic deve existir
      expect(find.byIcon(Icons.mic_none), findsOneWidget);

      // Tap no mic
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();

      // Deve mudar para ícone ativo
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Simula resultado parcial
      fakeSpeech.simulateResult('olá mundo');
      await tester.pump();

      // Campo deve ter o texto
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'olá mundo');
    });

    testWidgets('permissão negada mostra toast de erro', (tester) async {
      final fakeSpeech = FakeSpeechService(shouldBeAvailable: false);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatInput(
              onSend: (_) {},
              speechService: fakeSpeech,
            ),
          ),
        ),
      );

      // Tap no mic
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();

      // SnackBar de erro deve aparecer
      expect(find.text('Microfone ou reconhecimento de fala indisponível. '
          'Verifique as permissões em Preferências do Sistema.'),
          findsOneWidget);

      // Ícone não deve mudar para ativo
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
    });

    testWidgets('tap novamente para de ouvir', (tester) async {
      final fakeSpeech = FakeSpeechService(shouldBeAvailable: true);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ChatInput(
              onSend: (_) {},
              speechService: fakeSpeech,
            ),
          ),
        ),
      );

      // Inicia
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Para
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });
  });
}
