import 'dart:io';
import 'package:flutter/services.dart';

bool get isSupported => Platform.isAndroid || Platform.isIOS;

class _GalleryExporterChannel {
  static const MethodChannel channel = MethodChannel('clutch_scenarios/export');
}

Future<bool> saveImage({
  required Uint8List pngBytes,
  required String fileName,
}) async {
  if (!isSupported) {
    return false;
  }
  try {
    final bool? result =
        await _GalleryExporterChannel.channel.invokeMethod<bool>(
      'saveImage',
      {
        'fileName': fileName,
        'bytes': pngBytes,
      },
    );
    return result ?? false;
  } on MissingPluginException {
    return false;
  } catch (_) {
    return false;
  }
}
