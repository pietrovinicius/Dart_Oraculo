import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Bolha de mensagem no chat (user ou assistant).
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.content,
    required this.isUser,
    this.modelUsed,
    this.feedback,
    this.isVerifying = false,
    this.onFeedbackChanged,
    this.timestamp,
    this.onEdit,
    this.imagePath,
  });

  final String content;
  final bool isUser;
  final String? modelUsed;
  final String? feedback;
  final bool isVerifying;
  final void Function(String? value)? onFeedbackChanged;
  final DateTime? timestamp;
  final void Function(String newText)? onEdit;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? AppColors.accentOrange.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
          border: Border.all(
            color: isUser ? AppColors.accentOrange.withValues(alpha: 0.3) : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniatura da imagem anexada (se presente)
            if (isUser && imagePath != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imagePath!),
                  width: 200,
                  height: 150,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Conteúdo — markdown para assistant, texto selecionável para user
            if (isUser)
              SelectableText(content, style: AppTextStyles.bodyLarge)
            else
              MarkdownBody(
                data: content,
                selectable: true,
                builders: {
                  'code': _CodeBlockBuilder(),
                },
                styleSheet: MarkdownStyleSheet(
                  p: AppTextStyles.bodyLarge,
                  h1: AppTextStyles.displayMedium.copyWith(fontSize: 22),
                  h2: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  h3: AppTextStyles.bodyLarge.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  code: AppTextStyles.techMedium.copyWith(
                    backgroundColor: AppColors.surfaceLight,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  listBullet: AppTextStyles.bodyLarge,
                  blockquoteDecoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: AppColors.accentOrange.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                  ),
                ),
              ),

            // Footer: modelo + timestamp + feedback + copy + edit
            if (modelUsed != null || timestamp != null || (isUser && onEdit != null) || (!isUser && onFeedbackChanged != null)) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (modelUsed != null) ...[                    Icon(
                      modelUsed!.contains('qwen')
                          ? Icons.computer_outlined
                          : Icons.cloud_outlined,
                      size: 12,
                      color: modelUsed!.contains('qwen')
                          ? AppColors.success
                          : AppColors.accentOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(modelUsed!, style: AppTextStyles.techSmall),
                  ],
                  if (timestamp != null) ...[
                    if (modelUsed != null) const SizedBox(width: 8),
                    Text(
                      '${timestamp!.hour.toString().padLeft(2, '0')}:${timestamp!.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.techSmall,
                    ),
                  ],
                  const Spacer(),
                  // Editar (só user)
                  if (isUser && onEdit != null)
                    _ActionButton(
                      icon: Icons.edit_outlined,
                      tooltip: 'Editar',
                      onTap: () => onEdit!(content),
                    ),
                  // Copiar
                  if (!isUser)
                    _ActionButton(
                      icon: Icons.copy_outlined,
                      tooltip: 'Copiar',
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: content));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Copiado'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  // Feedback
                  if (!isUser && onFeedbackChanged != null) ...[
                    const SizedBox(width: 4),
                    if (isVerifying)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.accentOrange,
                        ),
                      )
                    else
                    _FeedbackButton(
                      icon: Icons.thumb_up_outlined,
                      activeIcon: Icons.thumb_up,
                      isActive: feedback == 'like',
                      onTap: () => onFeedbackChanged!(
                        feedback == 'like' ? null : 'like',
                      ),
                    ),
                    const SizedBox(width: 4),
                    _FeedbackButton(
                      icon: Icons.thumb_down_outlined,
                      activeIcon: Icons.thumb_down,
                      isActive: feedback == 'dislike',
                      onTap: () => onFeedbackChanged!(
                        feedback == 'dislike' ? null : 'dislike',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 14, color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _FeedbackButton extends StatefulWidget {
  const _FeedbackButton({
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FeedbackButton> createState() => _FeedbackButtonState();
}

class _FeedbackButtonState extends State<_FeedbackButton> {
  double _scale = 1.0;

  void _handleTap() {
    setState(() => _scale = 1.3);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _scale = 1.0);
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _handleTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Icon(
            widget.isActive ? widget.activeIcon : widget.icon,
            size: 16,
            color: widget.isActive ? AppColors.accentOrange : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Builder customizado para code blocks com botão de copiar.
class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    return _CodeBlockWidget(code: code);
  }
}

class _CodeBlockWidget extends StatefulWidget {
  const _CodeBlockWidget({required this.code});
  final String code;

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _copied = false;

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.code));
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header com botão copy
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                const Spacer(),
                InkWell(
                  onTap: _copyCode,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _copied ? Icons.check : Icons.copy_outlined,
                          size: 14,
                          color: _copied ? AppColors.success : AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _copied ? 'Copiado' : 'Copiar',
                          style: AppTextStyles.techSmall.copyWith(
                            color: _copied ? AppColors.success : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Código
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              widget.code,
              style: AppTextStyles.techMedium,
            ),
          ),
        ],
      ),
    );
  }
}
