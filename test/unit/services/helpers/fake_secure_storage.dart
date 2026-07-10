import 'package:dart_oraculo/core/services/secure_storage_service.dart';

/// Fake de SecureStorageService para testes unitários.
/// Usa o `testStore` embutido do service real.
class FakeSecureStorage extends SecureStorageService {
  FakeSecureStorage() : super(testStore: {});

  Map<String, String> get store => testStore!;
}
