/// Configurações globais do Dart Oráculo.
class AppConfig {
  AppConfig._();

  static const String appName = 'Dart Oráculo';

  // API Anthropic
  static const String anthropicBaseUrl =
      'https://api.anthropic.com/v1/messages';
  static const String anthropicVersion = '2023-06-01';

  // Modelos disponíveis
  static const String modelSonnet = 'claude-sonnet-5-20250514';
  static const String modelOpus = 'claude-opus-4-8-20250514';
  static const String defaultModel = modelSonnet;

  // RAG
  static const int maxChunksPerQuery = 10;
  static const int chunkMaxTokens = 500;
  static const int maxHistoryMessages = 10;

  // Database
  static const String databaseName = 'dart_oraculo.db';
  static const int databaseVersion = 1;
}
