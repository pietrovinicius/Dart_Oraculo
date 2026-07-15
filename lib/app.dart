import 'package:flutter/material.dart';

import 'core/config/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/auth/lock_screen.dart';
import 'features/chat/chat_screen.dart';
import 'features/settings/settings_screen.dart';

class DartOraculoApp extends StatefulWidget {
  const DartOraculoApp({super.key});

  @override
  State<DartOraculoApp> createState() => _DartOraculoAppState();
}

class _DartOraculoAppState extends State<DartOraculoApp> {
  late final ThemeNotifier _themeNotifier;

  @override
  void initState() {
    super.initState();
    _themeNotifier = ThemeNotifier();
    _themeNotifier.load();
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeNotifier,
      builder: (context, _) => MaterialApp(
        title: 'Dart Oráculo',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: _themeNotifier.mode,
        initialRoute: AppRoutes.home,
        routes: {
          AppRoutes.lock: (_) => const LockScreen(),
          AppRoutes.home: (_) => ChatScreen(themeNotifier: _themeNotifier),
          AppRoutes.settings: (_) => SettingsScreen(themeNotifier: _themeNotifier),
        },
      ),
    );
  }
}
