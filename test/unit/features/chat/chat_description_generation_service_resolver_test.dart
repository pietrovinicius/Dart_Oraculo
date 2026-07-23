import 'package:dart_oraculo/core/config/app_config.dart';
import 'package:dart_oraculo/core/constants/storage_keys.dart';
import 'package:dart_oraculo/core/services/anthropic_service.dart';
import 'package:dart_oraculo/core/services/kimi_service.dart';
import 'package:dart_oraculo/core/services/ollama_service.dart';
import 'package:dart_oraculo/features/chat/chat_description_generation_service_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatDescriptionGenerationServiceResolver', () {
    test('retorna KimiService quando modelo selecionado é Kimi', () {
      final anthropic = AnthropicService(apiKey: 'sk-anthropic-test');
      final settings = <String, String?>{
        StorageKeys.kimiApiKey: 'sk-kimi-test',
        StorageKeys.apiKey: 'sk-anthropic-test',
      };

      final service = ChatDescriptionGenerationServiceResolver.resolve(
        selectedModel: AppConfig.modelKimi,
        anthropicService: anthropic,
        readSetting: (key) => settings[key],
      );

      expect(service, isA<KimiService>());
    });

    test('retorna null para Kimi sem chave configurada', () {
      final anthropic = AnthropicService(apiKey: 'sk-anthropic-test');
      final settings = <String, String?>{
        StorageKeys.apiKey: 'sk-anthropic-test',
      };

      final service = ChatDescriptionGenerationServiceResolver.resolve(
        selectedModel: AppConfig.modelKimi,
        anthropicService: anthropic,
        readSetting: (key) => settings[key],
      );

      expect(service, isNull);
    });

    test('retorna null para Kimi com chave vazia', () {
      final anthropic = AnthropicService(apiKey: 'sk-anthropic-test');
      final settings = <String, String?>{
        StorageKeys.kimiApiKey: '',
        StorageKeys.apiKey: 'sk-anthropic-test',
      };

      final service = ChatDescriptionGenerationServiceResolver.resolve(
        selectedModel: AppConfig.modelKimi,
        anthropicService: anthropic,
        readSetting: (key) => settings[key],
      );

      expect(service, isNull);
    });

    test('retorna OllamaService quando modelo selecionado é Qwen', () {
      final anthropic = AnthropicService(apiKey: 'sk-anthropic-test');

      final service = ChatDescriptionGenerationServiceResolver.resolve(
        selectedModel: AppConfig.modelQwen,
        anthropicService: anthropic,
        readSetting: (_) => null,
      );

      expect(service, isA<OllamaService>());
    });

    test('retorna AnthropicService quando modelo selecionado é Anthropic', () {
      final anthropic = AnthropicService(apiKey: 'sk-anthropic-test');
      final settings = <String, String?>{
        StorageKeys.apiKey: 'sk-anthropic-test',
      };

      final service = ChatDescriptionGenerationServiceResolver.resolve(
        selectedModel: AppConfig.modelSonnet,
        anthropicService: anthropic,
        readSetting: (key) => settings[key],
      );

      expect(service, same(anthropic));
    });

    test('retorna null para Anthropic sem chave configurada', () {
      final anthropic = AnthropicService(apiKey: '');

      final service = ChatDescriptionGenerationServiceResolver.resolve(
        selectedModel: AppConfig.modelSonnet,
        anthropicService: anthropic,
        readSetting: (_) => null,
      );

      expect(service, isNull);
    });

    test('retorna null para Anthropic com chave vazia', () {
      final anthropic = AnthropicService(apiKey: '');
      final settings = <String, String?>{
        StorageKeys.apiKey: '',
      };

      final service = ChatDescriptionGenerationServiceResolver.resolve(
        selectedModel: AppConfig.modelSonnet,
        anthropicService: anthropic,
        readSetting: (key) => settings[key],
      );

      expect(service, isNull);
    });
  });
}
