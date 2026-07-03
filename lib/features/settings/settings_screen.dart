import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'settings_controller.dart';

/// Tela de configurações — chave API, modelo padrão, toggle biometria.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;
  final _apiKeyController = TextEditingController();
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController(
      storageService: SecureStorageService(),
    );
    _controller.addListener(_onControllerChanged);
    _controller.load();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    if (!_controller.isLoading && _apiKeyController.text.isEmpty) {
      _apiKeyController.text = _controller.apiKey;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configurações'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _controller.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentOrange),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildApiKeySection(),
                  const SizedBox(height: 32),
                  _buildModelSection(),
                  const SizedBox(height: 32),
                  _buildBiometricSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildApiKeySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chave de API da Anthropic',
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Armazenada de forma segura no Keychain do macOS.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyController,
          obscureText: _obscureKey,
          style: AppTextStyles.techMedium,
          decoration: InputDecoration(
            hintText: 'sk-ant-...',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
                IconButton(
                  icon: const Icon(Icons.save, color: AppColors.accentOrange),
                  onPressed: () async {
                    await _controller.saveApiKey(_apiKeyController.text.trim());
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chave salva com sucesso.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Modelo padrão',
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: 12),
        _buildModelTile(
          title: 'Sonnet 5',
          subtitle: 'Rápido, ideal para perguntas cotidianas',
          value: AppConfig.modelSonnet,
        ),
        _buildModelTile(
          title: 'Opus 4.8',
          subtitle: 'Raciocínio mais profundo, ideal para análises complexas',
          value: AppConfig.modelOpus,
        ),
      ],
    );
  }

  Widget _buildModelTile({
    required String title,
    required String subtitle,
    required String value,
  }) {
    final isSelected = _controller.selectedModel == value;
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? AppColors.accentOrange : AppColors.textMuted,
      ),
      title: Text(title, style: AppTextStyles.bodyMedium),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      onTap: () => _controller.saveModel(value),
    );
  }

  Widget _buildBiometricSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Autenticação local',
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text(
            'Exigir Face ID / Touch ID ao abrir',
            style: AppTextStyles.bodyMedium,
          ),
          subtitle: const Text(
            'Protege contra acesso físico não autorizado',
            style: AppTextStyles.bodySmall,
          ),
          value: _controller.biometricEnabled,
          activeThumbColor: AppColors.accentOrange,
          onChanged: (value) => _controller.saveBiometric(value),
        ),
      ],
    );
  }
}
