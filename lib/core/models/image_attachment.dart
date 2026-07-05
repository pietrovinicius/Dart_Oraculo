import 'dart:typed_data';

/// Imagem anexada a uma mensagem de chat.
class ImageAttachment {
  const ImageAttachment({
    required this.bytes,
    required this.mediaType,
    this.path,
  });

  /// Bytes da imagem (já redimensionada).
  final Uint8List bytes;

  /// MIME type: 'image/png', 'image/jpeg', etc.
  final String mediaType;

  /// Caminho local salvo (preenchido após persistência).
  final String? path;
}
