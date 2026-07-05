import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Redimensiona imagens para no máximo [maxDimension] pixels no lado maior.
class ImageResizeService {
  static const int maxDimension = 1568;

  /// Retorna bytes redimensionados (PNG). Se já ≤ maxDimension, retorna intacto.
  static Future<Uint8List> resize(Uint8List bytes) async {
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (_) {
      return bytes;
    }
    if (decoded == null) return bytes;

    final maxSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;

    if (maxSide <= maxDimension) return bytes;

    final ratio = maxDimension / maxSide;
    final newWidth = (decoded.width * ratio).round();
    final newHeight = (decoded.height * ratio).round();

    final resized = img.copyResize(
      decoded,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );

    return Uint8List.fromList(img.encodePng(resized));
  }
}
