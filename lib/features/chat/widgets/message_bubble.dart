import 'package:flutter/material.dart';

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
  });

  final String content;
  final bool isUser;
  final String? modelUsed;
  final String? feedback;
  final void Function(String? value)? onFeedbackChanged;

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
            Text(
              content,
              style: AppTextStyles.bodyLarge,
            ),
            if (modelUsed != null || (!isUser && onFeedbackChanged != null)) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (modelUsed != null)
                    Text(modelUsed!, style: AppTextStyles.techSmall),
                  if (!isUser && onFeedbackChanged != null) ...[
                    const Spacer(),
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
