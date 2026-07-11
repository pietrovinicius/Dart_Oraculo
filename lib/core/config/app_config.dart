/// Configurações globais do Dart Oráculo.
class AppConfig {
  AppConfig._();

  static const String appName = 'Dart Oráculo';
  static const String appVersion = '0.31.0';

  // API Anthropic
  static const String anthropicBaseUrl =
      'https://api.anthropic.com/v1/messages';
  static const String anthropicVersion = '2023-06-01';

  // Modelos disponíveis
  static const String modelSonnet = 'claude-sonnet-4-6';
  static const String modelOpus = 'claude-opus-4-8';
  static const String modelKimi = 'kimi-k2.6';
  static const String modelQwen = 'qwen-local';
  static const String defaultModel = modelSonnet;

  // Ollama
  static const String ollamaBaseUrl = 'http://localhost:11434';
  static const String ollamaModel = 'qwen3.5:latest';

  // Kimi (Moonshot AI)
  static const String kimiBaseUrl = 'https://api.moonshot.ai/v1/chat/completions';
  static const String kimiModel = 'kimi-k2.6';

  // RAG
  static const int maxChunksPerQuery = 10;
  static const int chunkMaxTokens = 500;
  static const int maxHistoryMessages = 10;

  // Timeout HTTP
  static const Duration httpTimeout = Duration(seconds: 90);

  // Database
  static const String databaseName = 'dart_oraculo.db';
  static const int databaseVersion = 10;
}
