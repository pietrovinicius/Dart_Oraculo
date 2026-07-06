import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../collections/models/collection.dart';
import '../models/conversation.dart';

/// Sidebar retrátil com seletor de coleção, lista de conversas e documentos.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.collections,
    required this.activeCollectionId,
    required this.onCollectionChanged,
    required this.onNewCollection,
    required this.conversations,
    required this.selectedConversationId,
    required this.onConversationSelected,
    required this.onNewConversation,
    required this.onDeleteConversation,
    required this.onRenameConversation,
    required this.onTogglePin,
    this.onExportConversation,
    required this.documentCount,
    required this.onOpenDocuments,
    required this.onOpenLibrary,
    this.appVersion = '',
  });

  final List<Collection> collections;
  final int? activeCollectionId;
  final void Function(int id) onCollectionChanged;
  final VoidCallback onNewCollection;
  final List<Conversation> conversations;
  final int? selectedConversationId;
  final void Function(int id) onConversationSelected;
  final VoidCallback onNewConversation;
  final void Function(int id) onDeleteConversation;
  final void Function(int id, String newTitle) onRenameConversation;
  final void Function(int id, bool pinned) onTogglePin;
  final void Function(int id)? onExportConversation;
  final int documentCount;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenLibrary;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: Theme.of(context).brightness == Brightness.light
          ? Theme.of(context).colorScheme.surfaceContainerLow
          : Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // Seletor de coleção
          _buildCollectionSelector(context),
          Divider(color: Theme.of(context).dividerColor, height: 1),

          // Header conversas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Text('Conversas', style: AppTextStyles.bodyLarge),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.accentOrange, size: 20),
                  onPressed: onNewConversation,
                  tooltip: 'Nova conversa',
                ),
              ],
            ),
          ),
          Divider(color: Theme.of(context).dividerColor, height: 1),

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
                        leading: conv.pinned
                            ? const Icon(
                                Icons.push_pin,
                                size: 16,
                                color: AppColors.accentOrange,
                              )
                            : null,
                        title: Text(
                          conv.title ?? 'Sem título',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isSelected
                                ? AppColors.accentOrange
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        selected: isSelected,
                        selectedTileColor:
                            AppColors.accentOrange.withValues(alpha: 0.1),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                  SizedBox(width: 8),
                                  Text('Renomear', style: AppTextStyles.bodyMedium),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'pin',
                              child: Row(
                                children: [
                                  Icon(
                                    conv.pinned ? Icons.push_pin_outlined : Icons.push_pin,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    conv.pinned ? 'Desafixar' : 'Fixar',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'export',
                              child: Row(
                                children: [
                                  Icon(Icons.download_outlined, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                                  SizedBox(width: 8),
                                  Text('Exportar .md', style: AppTextStyles.bodyMedium),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Text('Excluir', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (action) {
                            switch (action) {
                              case 'rename':
                                _showRenameDialog(context, conv);
                              case 'pin':
                                onTogglePin(conv.id!, !conv.pinned);
                              case 'export':
                                onExportConversation?.call(conv.id!);
                              case 'delete':
                                onDeleteConversation(conv.id!);
                            }
                          },
                        ),
                        onTap: () => onConversationSelected(conv.id!),
                      );
                    },
                  ),
          ),

          // Seção de documentos
          Divider(color: Theme.of(context).dividerColor, height: 1),
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
            onTap: onOpenLibrary,
          ),

          // Rodapé de identificação
          Divider(color: Theme.of(context).dividerColor, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'v${appVersion.isNotEmpty ? appVersion : AppConfig.appVersion}',
                  style: AppTextStyles.techSmall,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Dev @PLima',
                  style: AppTextStyles.techSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.collections_bookmark, size: 18, color: AppColors.accentOrange),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButton<int>(
              value: activeCollectionId,
              isExpanded: true,
              dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              underline: const SizedBox.shrink(),
              items: collections.map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.name, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (id) {
                if (id != null) onCollectionChanged(id);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined, size: 18, color: AppColors.accentOrange),
            onPressed: onNewCollection,
            tooltip: 'Nova coleção',
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Conversation conv) {
    final controller = TextEditingController(text: conv.title ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Renomear conversa', style: AppTextStyles.bodyLarge),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppTextStyles.bodyLarge,
          decoration: const InputDecoration(
            hintText: 'Nome da conversa',
          ),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) {
              onRenameConversation(conv.id!, trimmed);
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                onRenameConversation(conv.id!, trimmed);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salvar', style: TextStyle(color: AppColors.accentOrange)),
          ),
        ],
      ),
    );
  }
}
