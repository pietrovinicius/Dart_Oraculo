# Plano de Implementação — Envio de Imagem no Chat

**Data:** 2026-07-05  
**Versão alvo:** v0.15.0  
**Escopo:** 1 imagem por mensagem, anexo pontual (não entra no RAG)

---

## Visão Geral

Permitir ao usuário anexar uma imagem (via file_picker ou Cmd+V) a uma pergunta no chat. A imagem é redimensionada para ≤1568px, enviada ao modelo (Anthropic ou Ollama), salva localmente para renderização no histórico, mas nunca indexada no pipeline RAG.

---

## Arquitetura

```
[ChatInput] → file_picker / Cmd+V (pasteboard) → bytes
                    ↓
[ImageResizeService] → ≤1568px no lado maior
                    ↓
[ChatScreen] → salva em AppSupport/chat_images/{uuid}.png
             → grava image_path na msg
             → passa ImageAttachment ao controller
                    ↓
[ChatController.askQuestion(image: ImageAttachment?)]
     → FTS5 busca normal sobre o texto
     → GenerationService.streamResponse(images: [...])
          ├─ AnthropicService → content block base64
          └─ OllamaService → campo images base64
```

---

## Novos Arquivos

| Arquivo | Responsabilidade |
|---|---|
| `lib/core/models/image_attachment.dart` | Modelo: bytes, mediaType, path? |
| `lib/core/services/image_resize_service.dart` | Redimensiona para ≤1568px |
| `lib/core/services/clipboard_image_service.dart` | Wrapper pasteboard, retorna bytes ou null |
| `test/unit/services/image_resize_service_test.dart` | Testes resize |
| `test/unit/services/clipboard_image_service_test.dart` | Testes clipboard |
| `test/unit/services/anthropic_image_test.dart` | Teste bloco imagem Anthropic |
| `test/unit/services/ollama_image_test.dart` | Teste campo images Ollama |
| `test/unit/database/migration_v5_test.dart` | Teste coluna image_path |
| `test/widget/message_bubble_image_test.dart` | Teste miniatura na bolha |

---

## Arquivos Alterados

| Arquivo | Mudança |
|---|---|
| `pubspec.yaml` | +`image: ^4.0.0`, +`pasteboard: ^1.3.0`, +`uuid: ^4.0.0` |
| `lib/core/config/app_config.dart` | `databaseVersion = 5` |
| `lib/core/database/database_helper.dart` | Migration v4→v5: ADD COLUMN image_path |
| `lib/core/database/migrations.dart` | Novo `upgradeV4toV5` |
| `lib/core/services/generation_service.dart` | Param `List<ImageAttachment>?` |
| `lib/core/services/anthropic_service.dart` | Monta content blocks imagem |
| `lib/core/services/ollama_service.dart` | Campo images no body |
| `lib/features/chat/models/message.dart` | Campo `imagePath` |
| `lib/features/chat/chat_controller.dart` | Param `ImageAttachment?` em askQuestion |
| `lib/features/chat/chat_screen.dart` | Salva imagem, texto default, passa ao controller |
| `lib/features/chat/widgets/chat_input.dart` | Botão 📎, Cmd+V, preview, remover |
| `lib/features/chat/widgets/message_bubble.dart` | Renderiza miniatura |

---

## Ordem de Implementação

### Task 1 — Modelo ImageAttachment
**Arquivo:** `lib/core/models/image_attachment.dart`  
**Dependência:** nenhuma  

```dart
import 'dart:typed_data';

class ImageAttachment {
  const ImageAttachment({
    required this.bytes,
    required this.mediaType,
    this.path,
  });

  final Uint8List bytes;
  final String mediaType; // 'image/png', 'image/jpeg'
  final String? path; // caminho local salvo
}
```

---

### Task 2 — ImageResizeService + Teste
**Arquivos:**  
- `lib/core/services/image_resize_service.dart`  
- `test/unit/services/image_resize_service_test.dart`  
**Dependência:** pubspec +`image: ^4.0.0`  

**Teste RED:**
```dart
test('reduz imagem > 1568px no lado maior', () async {
  // Cria imagem 3000x2000
  final large = img.Image(width: 3000, height: 2000);
  final bytes = Uint8List.fromList(img.encodePng(large));
  final result = await ImageResizeService.resize(bytes);
  final decoded = img.decodeImage(result)!;
  expect(decoded.width, 1568);
  expect(decoded.height, 1045); // proporcional
});

test('mantém imagem ≤ 1568px inalterada', () async {
  final small = img.Image(width: 800, height: 600);
  final bytes = Uint8List.fromList(img.encodePng(small));
  final result = await ImageResizeService.resize(bytes);
  final decoded = img.decodeImage(result)!;
  expect(decoded.width, 800);
  expect(decoded.height, 600);
});
```

**GREEN:**
```dart
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class ImageResizeService {
  static const int maxDimension = 1568;

  static Future<Uint8List> resize(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final maxSide = decoded.width > decoded.height
        ? decoded.width
        : decoded.height;

    if (maxSide <= maxDimension) return bytes;

    final ratio = maxDimension / maxSide;
    final newWidth = (decoded.width * ratio).round();
    final newHeight = (decoded.height * ratio).round();

    final resized = img.copyResize(
      decoded,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );

    return Uint8List.fromList(img.encodePng(resized));
  }
}
```

---

### Task 3 — Migration v5 (image_path) + Teste
**Arquivos:**  
- `lib/core/database/migrations.dart` (adicionar método)  
- `lib/core/database/database_helper.dart` (bump version, chamar migration)  
- `lib/core/config/app_config.dart` (version 5)  
- `test/unit/database/migration_v5_test.dart`  

**Teste RED:**
```dart
test('migration v5 adiciona coluna image_path', () async {
  final db = await openDatabase(inMemoryDatabasePath, version: 1,
    onCreate: (db, v) => db.execute(Migrations.allV4));
  // Simula upgrade
  await db.execute('ALTER TABLE messages ADD COLUMN image_path TEXT');
  final info = await db.rawQuery('PRAGMA table_info(messages)');
  final cols = info.map((r) => r['name'] as String).toList();
  expect(cols, contains('image_path'));
});
```

**GREEN:**
- `app_config.dart`: `databaseVersion = 5`
- `migrations.dart`: `static const upgradeV4toV5 = 'ALTER TABLE messages ADD COLUMN image_path TEXT';`
- `database_helper.dart`: no `onUpgrade`, adicionar `if (oldVersion < 5) await db.execute(Migrations.upgradeV4toV5);`

---

### Task 4 — Message model + imagePath
**Arquivo:** `lib/features/chat/models/message.dart`  

Adicionar campo:
```dart
final String? imagePath;
```

Atualizar constructor, `toMap()` e `fromMap()`.

---

### Task 5 — GenerationService interface + AnthropicService imagem + Teste
**Arquivos:**  
- `lib/core/services/generation_service.dart`  
- `lib/core/services/anthropic_service.dart`  
- `test/unit/services/anthropic_image_test.dart`  

**Mudança interface:**
```dart
Stream<String> streamResponse({
  required String systemPrompt,
  required List<Map<String, String>> history,
  required String question,
  List<ImageAttachment>? images, // NOVO
});
```

**Teste RED:**
```dart
test('monta content block de imagem base64 antes do texto', () async {
  final service = AnthropicService(apiKey: 'sk-test', httpClient: mockClient);
  // Verificar que o body do request contém content blocks na ordem:
  // [{type: image, source: {type: base64, media_type: image/png, data: ...}},
  //  {type: text, text: "pergunta"}]
});
```

**GREEN:**
Em `buildRequestBody`, quando `images` não é nulo, montar `content` como lista de blocks em vez de string simples:
```dart
final userContent = <Map<String, dynamic>>[];
if (images != null) {
  for (final img in images) {
    userContent.add({
      'type': 'image',
      'source': {
        'type': 'base64',
        'media_type': img.mediaType,
        'data': base64Encode(img.bytes),
      },
    });
  }
}
userContent.add({'type': 'text', 'text': userMessage});
```

---

### Task 6 — OllamaService imagem + Teste
**Arquivos:**  
- `lib/core/services/ollama_service.dart`  
- `test/unit/services/ollama_image_test.dart`  

**Teste RED:**
```dart
test('inclui campo images com base64 no body', () async {
  final service = OllamaService(httpClient: mockClient);
  // Verificar que o body JSON contém:
  // messages: [{role: user, content: "...", images: ["base64..."]}]
});
```

**GREEN:**
No `streamResponse`, quando `images` não é nulo, adicionar campo `images` na mensagem user:
```dart
final userMsg = <String, dynamic>{'role': 'user', 'content': question};
if (images != null && images.isNotEmpty) {
  userMsg['images'] = images.map((i) => base64Encode(i.bytes)).toList();
}
```

---

### Task 7 — ChatController aceita imagem
**Arquivo:** `lib/features/chat/chat_controller.dart`  

Adicionar param `ImageAttachment?` em `askQuestion`. Passar para `streamResponse`. Salvar `imagePath` na mensagem ao gravar no banco.

---

### Task 8 — ClipboardImageService + Teste
**Arquivos:**  
- `lib/core/services/clipboard_image_service.dart`  
- `test/unit/services/clipboard_image_service_test.dart`  
**Dependência:** pubspec +`pasteboard: ^1.3.0`  

**Implementação:**
```dart
import 'dart:typed_data';
import 'package:pasteboard/pasteboard.dart';

class ClipboardImageService {
  Future<Uint8List?> getImage() async {
    return await Pasteboard.image;
  }
}
```

---

### Task 9 — ChatInput: botão anexar + Cmd+V + preview
**Arquivo:** `lib/features/chat/widgets/chat_input.dart`  

- Botão 📎 (IconButton) ao lado do send
- `file_picker` restrito a imagens (`type: FileType.image`)
- Cmd+V: consulta `ClipboardImageService`, se bytes → anexo
- Preview: `Image.memory(bytes)` com 48px height + botão ✕
- Callback `onSendWithImage(String text, Uint8List bytes, String mediaType)`

---

### Task 10 — ChatScreen: salva imagem + texto default + integração
**Arquivo:** `lib/features/chat/chat_screen.dart`  

- Ao enviar com imagem:
  1. `ImageResizeService.resize(bytes)`
  2. Salvar em `AppSupport/chat_images/{uuid}.png`
  3. Se texto vazio → usar "descreva e analise esta imagem"
  4. Chamar `_sendMessage(text, imageAttachment)` com path

---

### Task 11 — MessageBubble: renderiza miniatura + Teste
**Arquivos:**  
- `lib/features/chat/widgets/message_bubble.dart`  
- `test/widget/message_bubble_image_test.dart`  

**Teste RED:**
```dart
testWidgets('exibe miniatura quando imagePath presente', (tester) async {
  // Criar arquivo temporário de imagem
  // Renderizar MessageBubble com imagePath apontando para ele
  // Verificar que Image widget está presente
  expect(find.byType(Image), findsOneWidget);
});
```

**GREEN:**
No build, antes do texto do user:
```dart
if (isUser && imagePath != null)
  ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.file(
      File(imagePath!),
      width: 200,
      height: 150,
      fit: BoxFit.cover,
    ),
  ),
```

---

## Pacotes Novos

| Pacote | Versão | Uso |
|---|---|---|
| `image` | ^4.0.0 | Redimensionamento |
| `pasteboard` | ^1.3.0 | Cmd+V imagem clipboard |
| `uuid` | ^4.0.0 | Nome único para arquivos salvos |

---

## Verificação Final

Após cada task:
- `flutter analyze` limpo
- `flutter test` passando
- Commit individual

Após todas:
- Changelog fragment em `changelog/`
- Build macOS para confirmar

---

## Notas

- Imagem **nunca** entra em `documents` ou `chunks`
- FTS5 busca normalmente sobre o texto da pergunta
- Se texto vazio + imagem → usar "descreva e analise esta imagem" como query FTS
- 1 imagem por mensagem nesta versão
