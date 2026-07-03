import 'package:flutter/material.dart';

import '../../core/config/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Tela principal — sidebar + painel de chat.
/// Implementação completa no Sprint 5.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Dart Oráculo', style: AppTextStyles.displayMedium.copyWith(fontSize: 20)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Chat — em construção',
          style: AppTextStyles.bodyLarge,
        ),
      ),
    );
  }
}
