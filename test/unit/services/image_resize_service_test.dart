import 'dart:typed_data';

import 'package:dart_oraculo/core/services/image_resize_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  group('ImageResizeService', () {
    test('reduz imagem > 1568px no lado maior (landscape)', () async {
      final large = img.Image(width: 3000, height: 2000);
      final bytes = Uint8List.fromList(img.encodePng(large));

      final result = await ImageResizeService.resize(bytes);

      final decoded = img.decodePng(result)!;
      expect(decoded.width, 1568);
      expect(decoded.height, 1045);
    });

    test('reduz imagem > 1568px no lado maior (portrait)', () async {
      final large = img.Image(width: 1200, height: 2400);
      final bytes = Uint8List.fromList(img.encodePng(large));

      final result = await ImageResizeService.resize(bytes);

      final decoded = img.decodePng(result)!;
      expect(decoded.width, 784);
      expect(decoded.height, 1568);
    });

    test('mantém imagem ≤ 1568px inalterada', () async {
      final small = img.Image(width: 800, height: 600);
      final bytes = Uint8List.fromList(img.encodePng(small));

      final result = await ImageResizeService.resize(bytes);

      final decoded = img.decodePng(result)!;
      expect(decoded.width, 800);
      expect(decoded.height, 600);
    });

    test('retorna bytes intactos se decode falhar', () async {
      final garbage = Uint8List.fromList([0, 1, 2, 3, 4]);

      final result = await ImageResizeService.resize(garbage);

      expect(result, garbage);
    });
  });
}
