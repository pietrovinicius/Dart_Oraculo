import 'package:flutter/material.dart';

import 'core/config/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/lock_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/settings/settings_screen.dart';

class DartOraculoApp extends StatelessWidget {
  const DartOraculoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dart Oráculo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      initialRoute: AppRoutes.lock,
      routes: {
        AppRoutes.lock: (_) => const LockScreen(),
        AppRoutes.home: (_) => const ChatScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
      },
    );
  }
}
