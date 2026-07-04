import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
    this.onFeedbackChanged,
    this.timestamp,
  });

  final String content;
  final bool isUser;
  final String? modelUsed;
  final String? feedback;
  final void Function(String? value)? onFeedbackChanged;
  final DateTime? timestamp;

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
            // Conteúdo — markdown para assistant, texto selecionável para user
            if (isUser)
              SelectableText(content, style: AppTextStyles.bodyLarge)
            else
              MarkdownBody(
                data: content,
                selectable: true,
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

            // Footer: modelo + timestamp + feedback + copy
            if (modelUsed != null || (!isUser && onFeedbackChanged != null) || timestamp != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (modelUsed != null)
                    Text(modelUsed!, style: AppTextStyles.techSmall),
                  if (timestamp != null) ...[
                    if (modelUsed != null) const SizedBox(width: 8),
                    Text(
                      '${timestamp!.hour.toString().padLeft(2, '0')}:${timestamp!.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.techSmall,
                    ),
                  ],
                  const Spacer(),
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

class _FeedbackButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          isActive ? activeIcon : icon,
          size: 16,
          color: isActive ? AppColors.accentOrange : AppColors.textMuted,
        ),
      ),
    );
  }
}
