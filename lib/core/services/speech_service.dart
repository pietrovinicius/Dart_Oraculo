import 'dart:io';

import 'package:speech_to_text/speech_to_text.dart';

/// Wrapper sobre speech_to_text, injetável e mockável.
class SpeechService {
  SpeechService({SpeechToText? speechToText})
      : _speech = speechToText;

  final SpeechToText? _speech;
  bool _isAvailable = false;

  /// Se está ouvindo no momento.
  bool get isListening => _speech?.isListening ?? false;

  /// Inicializa e verifica disponibilidade + permissões.
  /// Retorna false se indisponível ou permissão negada.
  Future<bool> initialize() async {
    final speech = _speech;
    if (speech == null) return false;
    _isAvailable = await speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _isAvailable;
  }

  /// Inicia escuta. [onResult] recebe texto parcial em tempo real.
  /// Idioma: locale do sistema convertido para BCP-47.
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    String? localeId,
  }) async {
    final speech = _speech;
    if (!_isAvailable || speech == null) return;
    final locale = localeId ?? Platform.localeName.replaceAll('_', '-');
    await speech.listen(
      onResult: (result) => onResult(
        result.recognizedWords,
        result.finalResult,
      ),
      localeId: locale,
      listenMode: ListenMode.dictation,
      cancelOnError: false,
      partialResults: true,
    );
  }

  /// Para escuta.
  Future<void> stopListening() async {
    await _speech?.stop();
  }
}
