// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

bool get isSupported => true;

Future<bool> saveImage({
  required Uint8List pngBytes,
  required String fileName,
}) async {
  final blob = html.Blob(<dynamic>[pngBytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  try {
    final anchor = html.AnchorElement(href: url)
      ..download = fileName
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    return false;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
