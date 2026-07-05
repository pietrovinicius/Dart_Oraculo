import 'package:dart_oraculo/core/services/speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake do SpeechService para testes — não depende de SpeechToText real.
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

  /// Simula resultado de reconhecimento.
  void simulateResult(String text, {bool isFinal = false}) {
    _onResult?.call(text, isFinal);
  }
}

void main() {
  group('SpeechService (via FakeSpeechService)', () {
    test('initialize retorna true quando disponível', () async {
      final service = FakeSpeechService(shouldBeAvailable: true);

      final result = await service.initialize();

      expect(result, isTrue);
    });

    test('initialize retorna false quando permissão negada', () async {
      final service = FakeSpeechService(shouldBeAvailable: false);

      final result = await service.initialize();

      expect(result, isFalse);
    });

    test('startListening inicia escuta e recebe resultados', () async {
      final service = FakeSpeechService(shouldBeAvailable: true);
      await service.initialize();

      String? received;
      bool? wasFinal;

      await service.startListening(
        onResult: (text, isFinal) {
          received = text;
          wasFinal = isFinal;
        },
      );

      expect(service.isListening, isTrue);

      // Simula resultado parcial
      service.simulateResult('olá mundo', isFinal: false);
      expect(received, 'olá mundo');
      expect(wasFinal, isFalse);

      // Simula resultado final
      service.simulateResult('olá mundo completo', isFinal: true);
      expect(received, 'olá mundo completo');
      expect(wasFinal, isTrue);
    });

    test('stopListening para a escuta', () async {
      final service = FakeSpeechService(shouldBeAvailable: true);
      await service.initialize();
      await service.startListening(onResult: (_, __) {});

      expect(service.isListening, isTrue);

      await service.stopListening();

      expect(service.isListening, isFalse);
    });

    test('startListening não faz nada se indisponível', () async {
      final service = FakeSpeechService(shouldBeAvailable: false);
      await service.initialize();

      await service.startListening(onResult: (_, __) {});

      expect(service.isListening, isFalse);
    });
  });
}
