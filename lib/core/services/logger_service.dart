import 'dart:io';

import 'package:flutter/foundation.dart';

/// Logger centralizado — escreve em console e em log.txt na raiz do projeto.
class LoggerService {
  LoggerService._();

  static final LoggerService instance = LoggerService._();

  File? _logFile;

  /// Inicializa com o caminho raiz do projeto.
  void init({String? logFilePath}) {
    if (logFilePath != null) {
      _logFile = File(logFilePath);
    }
  }

  /// Log de informação.
  void info(String tag, String message) {
    _log('INFO', tag, message);
  }

  /// Log de erro.
  void error(String tag, String message, [Object? error, StackTrace? stack]) {
    _log('ERROR', tag, '$message${error != null ? ' | $error' : ''}');
    if (stack != null) {
      _log('ERROR', tag, stack.toString());
    }
  }

  /// Log de warning.
  void warn(String tag, String message) {
    _log('WARN', tag, message);
  }

  void _log(String level, String tag, String message) {
    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $level [$tag] $message';

    // Console
    debugPrint(line);

    // Arquivo
    _logFile?.writeAsStringSync('$line\n', mode: FileMode.append);
  }
}
