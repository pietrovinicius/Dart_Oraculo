import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/conversation.dart';

/// Sidebar retrátil com lista de conversas e biblioteca de documentos.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.conversations,
    required this.selectedConversationId,
    required this.onConversationSelected,
    required this.onNewConversation,
    required this.onDeleteConversation,
    required this.documentCount,
    required this.onOpenDocuments,
  });

  final List<Conversation> conversations;
  final int? selectedConversationId;
  final void Function(int id) onConversationSelected;
  final VoidCallback onNewConversation;
  final void Function(int id) onDeleteConversation;
  final int documentCount;
  final VoidCallback onOpenDocuments;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: AppColors.surface,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('Conversas', style: AppTextStyles.bodyLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.accentOrange),
                  onPressed: onNewConversation,
                  tooltip: 'Nova conversa',
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),

          // Lista de conversas
          Expanded(
            child: conversations.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma conversa',
                      style: AppTextStyles.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      final isSelected = conv.id == selectedConversationId;
                      return ListTile(
                        title: Text(
                          conv.title ?? 'Sem título',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected
                                ? AppColors.accentOrange
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: isSelected,
                        selectedTileColor:
                            AppColors.accentOrange.withValues(alpha: 0.1),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: AppColors.textMuted,
                          onPressed: () => onDeleteConversation(conv.id!),
                        ),
                        onTap: () => onConversationSelected(conv.id!),
                      );
                    },
                  ),
          ),

          // Seção de documentos
          const Divider(color: AppColors.divider, height: 1),
          ListTile(
            leading: const Icon(Icons.folder_outlined, color: AppColors.accentOrange),
            title: Text(
              'Documentos ($documentCount)',
              style: AppTextStyles.bodyMedium,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.add, color: AppColors.accentOrange),
              onPressed: onOpenDocuments,
              tooltip: 'Importar documento',
            ),
          ),
        ],
      ),
    );
  }
}
