import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'core/services/logger_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Inicializa logger — log.txt no diretório de suporte do app
  final appDir = await getApplicationSupportDirectory();
  final logPath = '${appDir.path}/log.txt';
  LoggerService.instance.init(logFilePath: logPath);
  LoggerService.instance.info('App', 'Dart Oráculo iniciando...');
  LoggerService.instance.info('App', 'Log file: $logPath');

  // Também imprime path no console para fácil acesso
  debugPrint('📄 Log file: $logPath');

  runApp(const DartOraculoApp());
}
