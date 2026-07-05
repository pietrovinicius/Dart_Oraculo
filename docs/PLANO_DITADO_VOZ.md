# Plano de Implementação — Ditado por Voz no Chat

**Data:** 2026-07-05  
**Versão alvo:** v0.16.0  
**Escopo:** Transcrição de fala para texto (speech-to-text) — sem síntese de voz

---

## Visão Geral

Botão de microfone no chat_input que usa Speech framework da Apple (via speech_to_text) para transcrever fala em tempo real no campo de texto. Idioma: locale do sistema (`Platform.localeName`).

---

## Novo Pacote

| Pacote | Versão | Uso |
|---|---|---|
| `speech_to_text` | ^7.0.0 | Reconhecimento de fala nativo macOS |

---

## Configurações Nativas (macOS)

### Info.plist (`macos/Runner/Info.plist`)
```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Dart Oráculo usa reconhecimento de fala para transcrever suas perguntas por voz.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Dart Oráculo precisa acessar o microfone para o ditado por voz.</string>
```

### Entitlements (`macos/Runner/DebugProfile.entitlements` e `Release.entitlements`)
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

---

## Arquivos Novos

| Arquivo | Responsabilidade |
|---|---|
| `lib/core/services/speech_service.dart` | Wrapper sobre speech_to_text, injetável/mockável |
| `test/unit/services/speech_service_test.dart` | Teste de fluxo (mock do pacote) |
| `test/widget/chat_input_speech_test.dart` | Widget test botão mic + transcrição |

---

## Arquivos Alterados

| Arquivo | Mudança |
|---|---|
| `pubspec.yaml` | +`speech_to_text: ^7.0.0` |
| `macos/Runner/Info.plist` | +NSSpeechRecognitionUsageDescription, +NSMicrophoneUsageDescription |
| `macos/Runner/DebugProfile.entitlements` | +com.apple.security.device.audio-input |
| `macos/Runner/Release.entitlements` | +com.apple.security.device.audio-input |
| `lib/features/chat/widgets/chat_input.dart` | Botão mic + estado escutando + resultado parcial no TextField |

---

## Ordem de Implementação

### Task 1 — Pacote + configurações nativas

1. Adicionar `speech_to_text: ^7.0.0` ao pubspec
2. Adicionar descriptions ao Info.plist
3. Adicionar entitlement de áudio em ambos entitlements
4. `flutter pub get`

---

### Task 2 — SpeechService wrapper + Teste

**Arquivo:** `lib/core/services/speech_service.dart`

```dart
import 'dart:io';

import 'package:speech_to_text/speech_to_text.dart';

/// Wrapper sobre speech_to_text, injetável e mockável.
class SpeechService {
  SpeechService({SpeechToText? speechToText})
      : _speech = speechToText ?? SpeechToText();

  final SpeechToText _speech;
  bool _isAvailable = false;

  bool get isListening => _speech.isListening;

  /// Inicializa e verifica disponibilidade + permissões.
  /// Retorna false se indisponível ou permissão negada.
  Future<bool> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    return _isAvailable;
  }

  /// Inicia escuta. [onResult] recebe texto parcial em tempo real.
  /// [localeId] default: locale do sistema.
  Future<void> startListening({
    required void Function(String text, bool isFinal) onResult,
    String? localeId,
  }) async {
    if (!_isAvailable) return;
    final locale = localeId ?? Platform.localeName.replaceAll('_', '-');
    await _speech.listen(
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
    await _speech.stop();
  }
}
```

**Teste RED:**
```dart
test('initialize retorna true quando disponível', () async {
  final mockSpeech = MockSpeechToText(); // mock do pacote
  when(mockSpeech.initialize(...)).thenAnswer((_) async => true);
  final service = SpeechService(speechToText: mockSpeech);
  expect(await service.initialize(), isTrue);
});

test('startListening chama listen com locale do sistema', () async {
  // verificar que _speech.listen é chamado
});

test('initialize retorna false quando permissão negada', () async {
  when(mockSpeech.initialize(...)).thenAnswer((_) async => false);
  final service = SpeechService(speechToText: mockSpeech);
  expect(await service.initialize(), isFalse);
});
```

---

### Task 3 — Botão mic no chat_input + Widget test

**Mudança em `chat_input.dart`:**

1. Aceitar `SpeechService?` como param (injeção)
2. Adicionar IconButton de microfone antes do botão send
3. Estado `_isListening` controla visual:
   - Parado: `Icons.mic_none` com cor textSecondary
   - Ouvindo: `Icons.mic` com cor accentOrange + animação pulse
4. Ao tocar:
   - Se não ouvindo → `speechService.initialize()` → se false, toast de erro → se true, `startListening(onResult: _onSpeechResult)`
   - Se ouvindo → `stopListening()`
5. `_onSpeechResult(text, isFinal)`: atualiza `_controller.text = text` em tempo real
6. Nunca envia automaticamente — texto fica editável

**Erro de permissão:**
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Microfone ou reconhecimento de fala indisponível. Verifique as permissões.'),
    backgroundColor: AppColors.error,
  ),
);
```

**Widget test RED:**
```dart
testWidgets('botão mic inicia escuta e popula campo', (tester) async {
  final mockSpeech = FakeSpeechService();
  // Verificar que ao tap no mic, campo recebe texto parcial
});

testWidgets('permissão negada mostra toast de erro', (tester) async {
  final mockSpeech = FakeSpeechService(available: false);
  // Verificar SnackBar de erro
});
```

---

### Task 4 — Verificação + Changelog + Commit

1. `flutter analyze` limpo
2. `flutter test` passando
3. Teste manual:
   - [ ] Digitar texto funciona normalmente
   - [ ] Cmd+V texto cola normalmente
   - [ ] Cmd+V imagem anexa normalmente
   - [ ] Botão mic inicia/para transcrição
4. Changelog fragment
5. Commit

---

## Verificação Final

- `flutter analyze` limpo
- `flutter test` passando (165+)
- Testes manuais reportados no changelog
- Commit individual

---

## Notas

- Idioma: `Platform.localeName` convertido para formato BCP-47 (pt-BR, en-US)
- Nunca envia automaticamente — texto transcrito é editável
- Sem síntese de voz nesta versão
- speech_to_text usa Speech framework nativo da Apple (on-device, sem API externa)
- Timeout de escuta: usar default do pacote (~30s inatividade)
