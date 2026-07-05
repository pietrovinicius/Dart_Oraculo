import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Mock do ClipboardImageService para testes.
class MockClipboardImageService {
  Uint8List? _imageData;

  void setImage(Uint8List? data) => _imageData = data;

  Future<Uint8List?> getImage() async => _imageData;
}

void main() {
  group('ClipboardImageService (mock)', () {
    late MockClipboardImageService service;

    setUp(() => service = MockClipboardImageService());

    test('retorna bytes quando imagem presente no clipboard', () async {
      final fakeImage = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      service.setImage(fakeImage);

      final result = await service.getImage();

      expect(result, isNotNull);
      expect(result, fakeImage);
    });

    test('retorna null quando clipboard não tem imagem', () async {
      service.setImage(null);

      final result = await service.getImage();

      expect(result, isNull);
    });
  });
}
