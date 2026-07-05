import 'dart:typed_data';

import 'package:pasteboard/pasteboard.dart';

/// Wrapper sobre Pasteboard para leitura de imagem do clipboard.
/// Injetável e mockável nos testes.
class ClipboardImageService {
  /// Retorna bytes PNG da imagem no clipboard, ou null se não houver.
  Future<Uint8List?> getImage() async {
    return Pasteboard.image;
  }
}
