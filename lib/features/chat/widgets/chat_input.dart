import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/clipboard_image_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Input de texto do chat com Enter para enviar, Shift+Enter para nova linha.
/// Suporta anexo de imagem via botão 📎 ou Cmd+V.
class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onSend,
    this.onSendWithImage,
    this.enabled = true,
    this.isStreaming = false,
    this.onStop,
    this.clipboardImageService,
  });

  final void Function(String message) onSend;
  final void Function(String message, Uint8List bytes, String mediaType)?
      onSendWithImage;
  final bool enabled;
  final bool isStreaming;
  final VoidCallback? onStop;
  final ClipboardImageService? clipboardImageService;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _focusNotifier = ValueNotifier<bool>(false);

  Uint8List? _attachedImage;
  String _attachedMediaType = 'image/png';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => _focusNotifier.value = _focusNode.hasFocus);
  }

  void _handleSend() {
    final text = _controller.text.trim();

    if (_attachedImage != null && widget.onSendWithImage != null) {
      widget.onSendWithImage!(text, _attachedImage!, _attachedMediaType);
      _controller.clear();
      setState(() => _attachedImage = null);
      _focusNode.requestFocus();
      return;
    }

    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final ext = file.extension?.toLowerCase() ?? 'png';
    final mediaType = ext == 'jpg' || ext == 'jpeg'
        ? 'image/jpeg'
        : ext == 'gif'
            ? 'image/gif'
            : ext == 'webp'
                ? 'image/webp'
                : 'image/png';

    setState(() {
      _attachedImage = file.bytes!;
      _attachedMediaType = mediaType;
    });
  }

  Future<void> _handlePaste() async {
    final clipService =
        widget.clipboardImageService ?? ClipboardImageService();
    final imageBytes = await clipService.getImage();
    if (imageBytes != null) {
      setState(() {
        _attachedImage = imageBytes;
        _attachedMediaType = 'image/png';
      });
    }
    // Se não tem imagem, não intercepta — colar texto funciona normalmente
  }

  void _removeAttachment() {
    setState(() => _attachedImage = null);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _focusNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _focusNotifier,
      builder: (context, isFocused, _) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(
                color: isFocused ? AppColors.accentOrange : AppColors.divider,
                width: isFocused ? 1.5 : 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview de imagem anexada
              if (_attachedImage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _attachedImage!,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _removeAttachment,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Botão anexar imagem
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: AppColors.textSecondary,
                    tooltip: 'Anexar imagem',
                    onPressed: widget.enabled ? _pickImage : null,
                    iconSize: 20,
                  ),
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter):
                            _handleSend,
                        const SingleActivator(
                          LogicalKeyboardKey.keyV,
                          meta: true,
                        ): _handlePaste,
                      },
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        style: AppTextStyles.bodyLarge,
                        decoration: const InputDecoration(
                          hintText:
                              'Pergunte ao Oráculo... (Shift+Enter nova linha)',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.isStreaming)
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined),
                      color: AppColors.error,
                      tooltip: 'Parar geração',
                      onPressed: widget.onStop,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: AppColors.accentOrange,
                      onPressed: widget.enabled ? _handleSend : null,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
