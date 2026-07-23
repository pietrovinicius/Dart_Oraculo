import '../../core/config/app_config.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/services/anthropic_service.dart';
import '../../core/services/generation_service.dart';
import '../../core/services/kimi_service.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/ollama_service.dart';

typedef SettingReader = String? Function(String key);

/// Resolve o provider usado para gerar descrições de documentos.
class ChatDescriptionGenerationServiceResolver {
  const ChatDescriptionGenerationServiceResolver._();

  static const _tag = 'ChatDescriptionGenerationServiceResolver';

  static GenerationService? resolve({
    required String selectedModel,
    required AnthropicService anthropicService,
    required SettingReader readSetting,
  }) {
    if (selectedModel == AppConfig.modelQwen) {
      return OllamaService();
    }

    if (selectedModel == AppConfig.modelKimi) {
      final kimiKey = readSetting(StorageKeys.kimiApiKey);
      if (kimiKey != null && kimiKey.isNotEmpty) {
        return KimiService(apiKey: kimiKey);
      }
      LoggerService.instance.warn(
        _tag,
        'Descrição via Kimi ignorada: chave Kimi não configurada.',
      );
      return null;
    }

    final apiKey = readSetting(StorageKeys.apiKey);
    if (apiKey != null && apiKey.isNotEmpty) {
      return anthropicService;
    }

    LoggerService.instance.warn(
      _tag,
      'Descrição via Anthropic ignorada: chave Anthropic não configurada.',
    );
    return null;
  }
}
