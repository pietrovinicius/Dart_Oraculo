import 'package:flutter/material.dart';

import '../../core/config/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'auth_service.dart';

/// Tela de bloqueio com autenticação biométrica via local_auth.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, this.authService});

  final AuthService? authService;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _errorMessage;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAuthenticate());
  }

  Future<void> _tryAuthenticate() async {
    final authService = widget.authService;
    if (authService == null) {
      _navigateHome();
      return;
    }

    setState(() {
      _authenticating = true;
      _errorMessage = null;
    });

    final result = await authService.authenticate();

    if (!mounted) return;

    switch (result) {
      case AuthResult.success:
        _navigateHome();
      case AuthResult.notConfigured:
        _navigateHome();
      case AuthResult.notAvailable:
        _navigateHome();
      case AuthResult.failed:
        setState(() {
          _authenticating = false;
          _errorMessage = 'Autenticação falhou. Tente novamente.';
        });
    }
  }

  void _navigateHome() {
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Dart Oráculo',
              style: AppTextStyles.displayLarge,
            ),
            const SizedBox(height: 48),
            if (_authenticating)
              const CircularProgressIndicator(
                color: AppColors.accentOrange,
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.fingerprint,
                  size: 64,
                  color: AppColors.accentOrange,
                ),
                onPressed: _tryAuthenticate,
              ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
              )
            else
              const Text(
                'Toque para desbloquear',
                style: AppTextStyles.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}
