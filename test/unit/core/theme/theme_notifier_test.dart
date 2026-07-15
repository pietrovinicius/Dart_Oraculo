import 'package:dart_oraculo/core/services/app_settings_cache.dart';
import 'package:dart_oraculo/core/services/error_feedback_service.dart';
import 'package:dart_oraculo/core/services/secure_storage_service.dart';
import 'package:dart_oraculo/core/theme/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake SecureStorage that can be configured to throw on write.
class FailingSecureStorage implements FlutterSecureStorage {
  final Map<String, String> _store = {};
  bool shouldThrowOnWrite = false;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (shouldThrowOnWrite) {
      throw Exception('Simulated Keychain write failure');
    }
    if (value != null) {
      _store[key] = value;
    } else {
      _store.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.remove(key);

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => Map.unmodifiable(_store);

  @override
  Future<void> deleteAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.clear();

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _store.containsKey(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ThemeNotifier', () {
    late ThemeNotifier notifier;
    late FailingSecureStorage storage;

    setUp(() {
      storage = FailingSecureStorage();
      notifier = ThemeNotifier();
      // Inject test storage
      ThemeNotifier.setStorageForTesting(
        SecureStorageService.test(storage: storage),
      );
    });

    tearDown(() {
      ThemeNotifier.clearStorageForTesting();
    });

    test('setMode succeeds when storage write succeeds', () async {
      storage.shouldThrowOnWrite = false;
      await notifier.setMode(ThemeMode.light);

      expect(notifier.mode, equals(ThemeMode.light));
      expect(storage._store['theme_mode'], equals('light'));
    });

    test('setMode reverts state on storage write failure (no context)',
        () async {
      final initialMode = notifier.mode;
      storage.shouldThrowOnWrite = true;

      // Should not rethrow, just revert
      await notifier.setMode(ThemeMode.light);

      expect(notifier.mode, equals(initialMode));
      expect(storage._store['theme_mode'], isNull);
    });

    testWidgets(
      'setMode shows critical error dialog when context provided and write fails',
      (tester) async {
        final initialMode = notifier.mode;
        storage.shouldThrowOnWrite = true;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => notifier.setMode(ThemeMode.light, context),
                  child: const Text('Toggle Theme'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        // State should revert
        expect(notifier.mode, equals(initialMode));

        // Error dialog should appear
        expect(find.byType(AlertDialog), findsOneWidget);
      },
    );

  });
}
