import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/secure_storage_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/theme_notifier.dart';
import 'settings_controller.dart';

/// Tela de configurações — chave API, modelo padrão, toggle biometria, tema.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.themeNotifier});

  final dynamic themeNotifier; // ThemeNotifier

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;
  final _apiKeyController = TextEditingController();
  // final _braveKeyController = TextEditingController(); // WEB_SEARCH_DISABLED
  bool _obscureKey = true;
  // bool _obscureBraveKey = true; // WEB_SEARCH_DISABLED
  bool _persistZoom = true;
  bool _generalKnowledge = false;

  @override
  void initState() {
    super.initState();
    _controller = SettingsController(
      storageService: SecureStorageService(),
    );
    _controller.addListener(_onControllerChanged);
    _controller.load();
    _loadZoomPref();
    _loadGeneralKnowledge();
    // _loadBraveKey(); // WEB_SEARCH_DISABLED
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
    if (!_controller.isLoading && _apiKeyController.text.isEmpty) {
      // Mostrar apenas versão parcial da chave: primeiros 10 + ... + últimos 4
      _apiKeyController.text = _maskApiKey(_controller.apiKey);
    }
  }

  String _maskApiKey(String key) {
    if (key.isEmpty) return '';
    if (key.length <= 14) return '••••••••';
    return '${key.substring(0, 10)}${'•' * 8}${key.substring(key.length - 4)}';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  // _buildBraveKeySection(), // WEB_SEARCH_DISABLED
                  // const SizedBox(height: 32), // WEB_SEARCH_DISABLED
                  _buildModelSection(),
                  const SizedBox(height: 32),
                  _buildGeneralKnowledgeSection(),
                  const SizedBox(height: 32),
                  _buildThemeSection(),
                  const SizedBox(height: 32),
                  _buildZoomSection(),
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
                    LoggerService.instance.info('SettingsScreen', 'Botão salvar API key pressionado');
                    final key = _apiKeyController.text.trim();
                    if (key.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Digite uma chave antes de salvar.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    // Não salvar se é a versão mascarada (não editou)
                    if (key.contains('••••')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Limpe o campo e cole a nova chave.'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }
                    try {
                      await _controller.saveApiKey(key);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chave salva com sucesso.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao salvar chave: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
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
          title: 'Sonnet',
          subtitle: 'Rápido, ideal para perguntas cotidianas',
          value: AppConfig.modelSonnet,
        ),
        _buildModelTile(
          title: 'Opus',
          subtitle: 'Raciocínio mais profundo, ideal para análises complexas',
          value: AppConfig.modelOpus,
        ),
        _buildModelTile(
          title: 'Qwen (Local)',
          subtitle: 'Offline via Ollama, sem custo de API',
          value: AppConfig.modelQwen,
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

  Widget _buildThemeSection() {
    final notifier = widget.themeNotifier;
    if (notifier is! ThemeNotifier) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Aparência', style: AppTextStyles.bodyLarge),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: notifier,
          builder: (context, _) => Column(
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('☀️  Claro', style: AppTextStyles.bodyMedium),
                value: ThemeMode.light,
                groupValue: notifier.mode,
                activeColor: AppColors.accentOrange,
                onChanged: (v) => notifier.setMode(v!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('🌙  Escuro', style: AppTextStyles.bodyMedium),
                value: ThemeMode.dark,
                groupValue: notifier.mode,
                activeColor: AppColors.accentOrange,
                onChanged: (v) => notifier.setMode(v!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('🖥️  Sistema', style: AppTextStyles.bodyMedium),
                subtitle: const Text('Segue configuração do macOS',
                    style: AppTextStyles.bodySmall),
                value: ThemeMode.system,
                groupValue: notifier.mode,
                activeColor: AppColors.accentOrange,
                onChanged: (v) => notifier.setMode(v!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  final _storage = SecureStorageService();

  Future<void> _loadGeneralKnowledge() async {
    final saved = await _storage.readRaw('general_knowledge_enabled');
    if (mounted) {
      setState(() => _generalKnowledge = saved == 'true');
    }
  }

  Widget _buildGeneralKnowledgeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Conhecimento geral', style: AppTextStyles.bodyLarge),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text(
            'Usar conhecimento do modelo',
            style: AppTextStyles.bodyMedium,
          ),
          subtitle: const Text(
            'Quando a base RAG não encontrar contexto, permite que o modelo '
            'responda com seu próprio conhecimento (Opus / Sonnet)',
            style: AppTextStyles.bodySmall,
          ),
          value: _generalKnowledge,
          activeColor: AppColors.accentOrange,
          onChanged: (v) async {
            setState(() => _generalKnowledge = v);
            await _storage.writeRaw('general_knowledge_enabled', v.toString());
          },
        ),
      ],
    );
  }

  Future<void> _loadZoomPref() async {
    final saved = await _storage.readRaw('persist_zoom');
    if (mounted) {
      setState(() => _persistZoom = saved != 'false');
    }
  }

  Widget _buildZoomSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Zoom do chat', style: AppTextStyles.bodyLarge),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text(
            'Lembrar zoom entre sessões',
            style: AppTextStyles.bodyMedium,
          ),
          subtitle: const Text(
            'Salva o nível de zoom escolhido no chat para a próxima abertura',
            style: AppTextStyles.bodySmall,
          ),
          value: _persistZoom,
          activeThumbColor: AppColors.accentOrange,
          onChanged: (value) async {
            setState(() => _persistZoom = value);
            await _storage.writeRaw('persist_zoom', value.toString());
            if (!value) {
              // Remove zoom salvo para resetar na próxima abertura
              await _storage.writeRaw('text_scale', '1.0');
            }
          },
        ),
      ],
    );
  }

  // --- WEB_SEARCH_DISABLED: Busca na internet removida — não é conceito do app ---
  // Future<void> _loadBraveKey() async {
  //   final key = await _storage.readRaw('brave_api_key');
  //   if (key != null && key.isNotEmpty && mounted) {
  //     _braveKeyController.text = '•' * 20;
  //   }
  // }
  //
  // Widget _buildBraveKeySection() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text('Busca na Internet', style: AppTextStyles.bodyLarge),
  //       const SizedBox(height: 4),
  //       Text(
  //         'Usado quando documentos locais não contêm a resposta.',
  //         style: AppTextStyles.bodySmall.copyWith(
  //           color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
  //         ),
  //       ),
  //       const SizedBox(height: 12),
  //       Row(
  //         children: [
  //           Expanded(
  //             child: TextField(
  //               controller: _braveKeyController,
  //               obscureText: _obscureBraveKey,
  //               style: AppTextStyles.techMedium,
  //               decoration: InputDecoration(
  //                 hintText: 'Brave Search API key',
  //                 suffixIcon: Row(
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: [
  //                     IconButton(
  //                       icon: Icon(_obscureBraveKey
  //                           ? Icons.visibility_off
  //                           : Icons.visibility),
  //                       onPressed: () => setState(
  //                           () => _obscureBraveKey = !_obscureBraveKey),
  //                     ),
  //                     IconButton(
  //                       icon: const Icon(Icons.save, color: AppColors.accentOrange),
  //                       onPressed: () async {
  //                         final key = _braveKeyController.text.trim();
  //                         if (key.isEmpty || key.startsWith('•')) return;
  //                         await _storage.writeRaw('brave_api_key', key);
  //                         if (mounted) {
  //                           _braveKeyController.text = '•' * 20;
  //                           ScaffoldMessenger.of(context).showSnackBar(
  //                             const SnackBar(
  //                               content: Text('Brave API key salva'),
  //                               backgroundColor: AppColors.success,
  //                             ),
  //                           );
  //                         }
  //                       },
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ],
  //   );
  // }
  // --- FIM WEB_SEARCH_DISABLED ---
}
