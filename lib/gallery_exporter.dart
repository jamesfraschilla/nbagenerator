import 'dart:typed_data';

import 'gallery_exporter_impl.dart' as impl;

class GalleryExporter {
  static bool get isSupported => impl.isSupported;

  static Future<bool> saveImage({
    required Uint8List pngBytes,
    required String fileName,
  }) {
    return impl.saveImage(pngBytes: pngBytes, fileName: fileName);
  }
}
