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
  final _kimiKeyController = TextEditingController();
  bool _obscureKey = true;
  bool _obscureKimiKey = true;
  bool _persistZoom = true;
  bool _generalKnowledge = false;
  bool _verifyFidelity = true;
  double _maxHistoryMessages = 10;
  double _maxChunksPerQuery = 10;
  double _chunkMaxTokens = 500;

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
    _loadFidelity();
    _loadAdvancedSettings();
    _loadKimiKey();
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

  Future<void> _loadKimiKey() async {
    final key = await SecureStorageService().getKimiApiKey();
    if (key != null && key.isNotEmpty && mounted) {
      setState(() => _kimiKeyController.text = _maskApiKey(key));
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _apiKeyController.dispose();
    _kimiKeyController.dispose();
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
                  _buildFidelitySection(),
                  const SizedBox(height: 32),
                  _buildThemeSection(),
                  const SizedBox(height: 32),
                  _buildZoomSection(),
                  const SizedBox(height: 32),
                  _buildBiometricSection(),
                  const SizedBox(height: 32),
                  _buildAdvancedSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildApiKeySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chaves de API', style: AppTextStyles.bodyLarge),
        const SizedBox(height: 4),
        const Text(
          'Armazenadas de forma segura no Keychain do macOS.',
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(height: 16),
        _buildApiKeyCard(
          providerName: 'Anthropic (Claude)',
          controller: _apiKeyController,
          obscure: _obscureKey,
          onToggleObscure: () => setState(() => _obscureKey = !_obscureKey),
          hintText: 'sk-ant-...',
          isConfigured: _apiKeyController.text.isNotEmpty,
          onSave: () => _saveAnthropicKey(),
        ),
        const SizedBox(height: 12),
        _buildApiKeyCard(
          providerName: 'Moonshot (Kimi)',
          controller: _kimiKeyController,
          obscure: _obscureKimiKey,
          onToggleObscure: () => setState(() => _obscureKimiKey = !_obscureKimiKey),
          hintText: 'sk-...',
          isConfigured: _kimiKeyController.text.isNotEmpty,
          onSave: () => _saveKimiKey(),
          isOptional: true,
        ),
      ],
    );
  }

  Widget _buildApiKeyCard({
    required String providerName,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleObscure,
    required String hintText,
    required bool isConfigured,
    required VoidCallback onSave,
    bool isOptional = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(providerName, style: AppTextStyles.bodyMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isConfigured
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.accentOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isConfigured ? '✅ Configurada' : '⚠️ Ausente',
                  style: AppTextStyles.techSmall.copyWith(
                    color: isConfigured ? AppColors.success : AppColors.accentOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: AppTextStyles.techMedium,
            decoration: InputDecoration(
              hintText: hintText,
              isDense: true,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.textMuted,
                      size: 18,
                    ),
                    onPressed: onToggleObscure,
                  ),
                  IconButton(
                    icon: const Icon(Icons.save, color: AppColors.accentOrange, size: 18),
                    onPressed: onSave,
                  ),
                ],
              ),
            ),
          ),
          if (isOptional) ...<Widget>[
            const SizedBox(height: 6),
            const Text(
              'Opcional — sem ela, o motor Kimi não aparece no seletor.',
              style: AppTextStyles.techSmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _saveAnthropicKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma chave antes de salvar.'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (key.contains('••••')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limpe o campo e cole a nova chave.'), backgroundColor: AppColors.error),
      );
      return;
    }
    try {
      await _controller.saveApiKey(key);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chave Anthropic salva.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _saveKimiKey() async {
    final key = _kimiKeyController.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite uma chave antes de salvar.'), backgroundColor: AppColors.error),
      );
      return;
    }
    if (key.contains('••••')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limpe o campo e cole a nova chave.'), backgroundColor: AppColors.error),
      );
      return;
    }
    try {
      await SecureStorageService().setKimiApiKey(key);
      if (mounted) {
        setState(() {}); // Atualiza indicador
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chave Kimi salva.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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
          title: 'Kimi K2.6',
          subtitle: 'Moonshot AI — janela 256K, custo baixo',
          value: AppConfig.modelKimi,
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

  Future<void> _loadFidelity() async {
    final saved = await _storage.readRaw('verify_before_promote_enabled');
    if (mounted) {
      setState(() => _verifyFidelity = saved != 'false');
    }
  }

  Widget _buildFidelitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verificação de fidelidade', style: AppTextStyles.bodyLarge),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text(
            'Checar antes de promover',
            style: AppTextStyles.bodyMedium,
          ),
          subtitle: const Text(
            'Verifica se a resposta é fiel aos documentos antes de '
            'promovê-la como conhecimento na base RAG',
            style: AppTextStyles.bodySmall,
          ),
          value: _verifyFidelity,
          activeColor: AppColors.accentOrange,
          onChanged: (v) async {
            setState(() => _verifyFidelity = v);
            await _storage.writeRaw('verify_before_promote_enabled', v.toString());
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

  Future<void> _loadAdvancedSettings() async {
    final histStr = await _storage.readRaw('max_history_messages');
    final chunksStr = await _storage.readRaw('max_chunks_per_query');
    final chunkSizeStr = await _storage.readRaw('chunk_max_tokens');
    if (mounted) {
      setState(() {
        _maxHistoryMessages = double.tryParse(histStr ?? '') ?? 10;
        _maxChunksPerQuery = double.tryParse(chunksStr ?? '') ?? 10;
        _chunkMaxTokens = double.tryParse(chunkSizeStr ?? '') ?? 500;
      });
    }
  }

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Avançado', style: AppTextStyles.bodyLarge),
        const SizedBox(height: 16),
        _buildSliderTile(
          label: 'Mensagens de contexto',
          subtitle: 'Quantas mensagens anteriores enviar ao modelo (mais = mais contexto, mais tokens)',
          value: _maxHistoryMessages,
          min: 5,
          max: 30,
          divisions: 5,
          storageKey: 'max_history_messages',
          onChanged: (v) => setState(() => _maxHistoryMessages = v),
        ),
        const SizedBox(height: 12),
        _buildSliderTile(
          label: 'Chunks por busca',
          subtitle: 'Máximo de trechos recuperados por pergunta (mais = respostas mais completas, mais tokens)',
          value: _maxChunksPerQuery,
          min: 3,
          max: 20,
          divisions: 17,
          storageKey: 'max_chunks_per_query',
          onChanged: (v) => setState(() => _maxChunksPerQuery = v),
        ),
        const SizedBox(height: 12),
        _buildSliderTile(
          label: 'Tamanho do chunk',
          subtitle: 'Tokens por trecho na indexação. Afeta apenas novos documentos.',
          value: _chunkMaxTokens,
          min: 200,
          max: 1000,
          divisions: 16,
          storageKey: 'chunk_max_tokens',
          onChanged: (v) => setState(() => _chunkMaxTokens = v),
        ),
      ],
    );
  }

  Widget _buildSliderTile({
    required String label,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String storageKey,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            Text('${value.round()}', style: AppTextStyles.bodyMedium),
          ],
        ),
        Text(subtitle, style: AppTextStyles.bodySmall),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: AppColors.accentOrange,
          label: '${value.round()}',
          onChanged: (v) {
            onChanged(v);
          },
          onChangeEnd: (v) async {
            await _storage.writeRaw(storageKey, '${v.round()}');
          },
        ),
      ],
    );
  }
}
