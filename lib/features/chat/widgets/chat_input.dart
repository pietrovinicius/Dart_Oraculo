import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Input de texto do chat com Enter para enviar, Shift+Enter para nova linha.
/// Mostra botão Stop durante streaming.
class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.onSend,
    this.enabled = true,
    this.isStreaming = false,
    this.onStop,
  });

  final void Function(String message) onSend;
  final bool enabled;
  final bool isStreaming;
  final VoidCallback? onStop;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _focusNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => _focusNotifier.value = _focusNode.hasFocus);
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();
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
          child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter): _handleSend,
              },
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                style: AppTextStyles.bodyLarge,
                decoration: const InputDecoration(
                  hintText: 'Pergunte ao Oráculo... (Shift+Enter nova linha)',
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
    );
      },
    );
  }
}
