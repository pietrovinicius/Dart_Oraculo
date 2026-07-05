# Plano de Implementação — Drag & Drop de Imagem no Chat

**Data:** 2026-07-05  
**Versão alvo:** v0.15.0 (mesma entrega)  
**Escopo:** Arrastar imagem do Finder → reusar infraestrutura existente de anexo

---

## Visão Geral

Permitir ao usuário arrastar uma imagem do Finder para a área do chat. Reusar 100% da infraestrutura já construída (ImageResizeService, preview no ChatInput, persistência, envio ao motor).

---

## Novo Pacote

| Pacote | Versão | Uso |
|---|---|---|
| `desktop_drop` | ^0.4.0 | DropTarget widget para macOS |

---

## Arquivos Alterados

| Arquivo | Mudança |
|---|---|
| `pubspec.yaml` | +`desktop_drop: ^0.4.0` |
| `lib/features/chat/chat_screen.dart` | Wrap painel de chat com DropTarget + feedback visual + validação |
| `test/widget/chat_screen_drop_test.dart` | Widget test drop válido e inválido |

---

## Implementação

### Task 1 — Adicionar desktop_drop ao pubspec

```yaml
# Em dependencies
desktop_drop: ^0.4.0
```

---

### Task 2 — Widget test RED (drop válido + inválido)

**Arquivo:** `test/widget/chat_screen_drop_test.dart`

Teste 1: Soltar arquivo .png aciona preview de imagem  
Teste 2: Soltar arquivo .txt mostra toast de erro sem quebrar UI

```dart
testWidgets('soltar imagem válida aciona preview', (tester) async {
  // Simular DropTarget drop com arquivo .png
  // Verificar que preview aparece (Image widget)
});

testWidgets('soltar arquivo inválido mostra erro', (tester) async {
  // Simular DropTarget drop com arquivo .txt
  // Verificar SnackBar de erro
  // Verificar que nenhum preview aparece
});
```

---

### Task 3 — DropTarget no chat_screen.dart (GREEN)

**Mudança:** Envolver o painel principal (Expanded que contém mensagens + input) com `DropTarget`.

```dart
import 'package:desktop_drop/desktop_drop.dart';

// No build, envolver o Column do painel principal:
DropTarget(
  onDragDone: _onDropDone,
  onDragEntered: (_) => setState(() => _isDragOver = true),
  onDragExited: (_) => setState(() => _isDragOver = false),
  child: Stack(
    children: [
      // Conteúdo existente (Column com toolbar + messages + input)
      existingColumn,
      // Overlay visual durante drag
      if (_isDragOver)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.accentOrange.withValues(alpha: 0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined,
                      size: 48, color: AppColors.accentOrange.withValues(alpha: 0.7)),
                  SizedBox(height: 8),
                  Text('Solte a imagem aqui',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.accentOrange)),
                ],
              ),
            ),
          ),
        ),
    ],
  ),
)
```

**Método `_onDropDone`:**
```dart
void _onDropDone(DropDoneDetails details) async {
  setState(() => _isDragOver = false);

  if (details.files.isEmpty) return;
  final file = details.files.first;
  
  // Valida extensão
  final ext = file.name.split('.').last.toLowerCase();
  const validExts = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
  if (!validExts.contains(ext)) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Formato inválido: .$ext — aceito: JPG, PNG, GIF, WebP'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    return;
  }

  // Lê bytes e reusar fluxo existente
  final bytes = await file.readAsBytes();
  final mediaType = ext == 'jpg' || ext == 'jpeg'
      ? 'image/jpeg'
      : ext == 'gif' ? 'image/gif'
      : ext == 'webp' ? 'image/webp'
      : 'image/png';

  _sendMessageWithImage('', Uint8List.fromList(bytes), mediaType);
}
```

**Nota:** `_sendMessageWithImage` já faz resize + salva + texto default.

---

### Task 4 — Estado `_isDragOver`

Adicionar ao estado:
```dart
bool _isDragOver = false;
```

---

### Task 5 — Verificação manual (4 cenários)

Antes de commitar, testar manualmente com app rodando:

1. ✓ Scroll da lista de mensagens funciona com DropTarget envolvendo
2. ✓ Seleção de texto nas bolhas funciona
3. ✓ Cmd+V texto cola normalmente
4. ✓ Cmd+V imagem anexa normalmente

Reportar resultado explícito no changelog.

---

### Task 6 — Changelog fragment + Commit

Fragmento em `changelog/changelog_v0.15.0_2026-07-05_drag-drop-imagem.md`.

---

## Verificação Final

- `flutter analyze` limpo
- `flutter test` passando (164+)
- Testes manuais reportados no changelog
- Commit individual

---

## Notas

- DropTarget não conflita com scroll — escuta eventos de drag do OS, não gestos Flutter
- Reuso total: ImageResizeService + persistência + _sendMessageWithImage
- Se user solta múltiplos arquivos, só o primeiro é usado (1 imagem/msg)
- Feedback visual sutil: overlay laranja transparente + ícone + texto
