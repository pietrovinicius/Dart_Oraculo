import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/clipboard_image_service.dart';
import '../../../core/services/speech_service.dart';
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
    this.speechService,
    this.selectedModel,
    this.onModelChanged,
  });

  final void Function(String message) onSend;
  final void Function(String message, Uint8List bytes, String mediaType)?
      onSendWithImage;
  final bool enabled;
  final bool isStreaming;
  final VoidCallback? onStop;
  final ClipboardImageService? clipboardImageService;
  final SpeechService? speechService;
  final String? selectedModel;
  final void Function(String model)? onModelChanged;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _focusNotifier = ValueNotifier<bool>(false);

  Uint8List? _attachedImage;
  String _attachedMediaType = 'image/png';
  bool _isListening = false;
  SpeechService? _speechService;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => _focusNotifier.value = _focusNode.hasFocus);
    _speechService = widget.speechService ?? SpeechService();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speechService!.stopListening();
      setState(() => _isListening = false);
      return;
    }

    final available = await _speechService!.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Microfone ou reconhecimento de fala indisponível. '
              'Verifique as permissões em Preferências do Sistema.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    setState(() => _isListening = true);
    await _speechService!.startListening(
      onResult: (text, isFinal) {
        if (mounted) {
          setState(() => _controller.text = text);
          // Move cursor para o final
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        }
        if (isFinal) {
          setState(() => _isListening = false);
        }
      },
    );
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

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    // Só intercepta Cmd+V key down
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final meta = HardwareKeyboard.instance.isMetaPressed;
    if (!meta || event.logicalKey != LogicalKeyboardKey.keyV) {
      return KeyEventResult.ignored;
    }
    // Verifica clipboard assincronamente
    _handlePaste();
    // Retorna ignored para permitir que o paste de texto funcione normalmente
    // se não houver imagem. _handlePaste() vai sobrepor com o anexo se encontrar imagem.
    return KeyEventResult.ignored;
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
    // Se não tem imagem, não intercepta — texto cola normalmente pelo TextField
  }

  void _removeAttachment() {
    setState(() => _attachedImage = null);
  }

  String _modelLabel(String model) {
    if (model.contains('sonnet')) return 'Sonnet';
    if (model.contains('opus')) return 'Opus';
    if (model.contains('qwen')) return 'Qwen';
    return model;
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
            color: Theme.of(context).colorScheme.surface,
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
              // Input row — TextField
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Botão anexar imagem
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    tooltip: 'Anexar imagem',
                    onPressed: widget.enabled ? _pickImage : null,
                    iconSize: 20,
                  ),
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter):
                            _handleSend,
                      },
                      child: Focus(
                        onKeyEvent: _onKeyEvent,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          enabled: widget.enabled,
                          style: AppTextStyles.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'Pergunte ao Oráculo...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          minLines: 1,
                          textInputAction: TextInputAction.newline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Bottom row — modelo + mic + send
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Seletor de modelo
                  if (widget.selectedModel != null && widget.onModelChanged != null)
                    PopupMenuButton<String>(
                      tooltip: 'Escolher modelo',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _modelLabel(widget.selectedModel!),
                              style: AppTextStyles.techSmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            Icon(Icons.arrow_drop_down,
                                size: 16,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                          ],
                        ),
                      ),
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: AppConfig.modelSonnet, child: Text('Sonnet')),
                        const PopupMenuItem(value: AppConfig.modelOpus, child: Text('Opus')),
                        const PopupMenuItem(value: AppConfig.modelQwen, child: Text('Qwen (Local)')),
                      ],
                      onSelected: widget.onModelChanged,
                    ),
                  const Spacer(),
                  // Microfone
                  AnimatedScale(
                    scale: _isListening ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                      ),
                      color: _isListening
                          ? AppColors.accentOrange
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      tooltip: _isListening ? 'Parar ditado' : 'Ditado por voz',
                      onPressed: widget.enabled ? _toggleListening : null,
                      iconSize: 22,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Send / Stop
                  if (widget.isStreaming)
                    IconButton(
                      icon: const Icon(Icons.stop_circle_outlined),
                      color: AppColors.error,
                      tooltip: 'Parar geração',
                      onPressed: widget.onStop,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: widget.enabled
                            ? AppColors.accentOrange
                            : AppColors.accentOrange.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_upward, size: 20),
                        color: Colors.white,
                        onPressed: widget.enabled ? _handleSend : null,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                ],
              ),
              // Disclaimer
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Dart Oráculo é uma IA e pode cometer erros. Verifique as respostas.',
                  style: AppTextStyles.techSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
