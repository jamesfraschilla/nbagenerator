import 'dart:io';

import 'storage_backend.dart';

class _IoStorageBackend implements StorageBackend {
  _IoStorageBackend({required this.namespace});

  final String namespace;
  Directory? _cachedDir;

  @override
  Future<bool> exists(String key) async {
    final file = await _file(key);
    return file.exists();
  }

  @override
  Future<String?> readText(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> writeText(String key, String value) async {
    final file = await _file(key);
    await file.writeAsString(value);
  }

  Future<File> _file(String key) async {
    final dir = await _root();
    return File('${dir.path}/$key');
  }

  Future<Directory> _root() async {
    final cached = _cachedDir;
    if (cached != null) return cached;

    final Directory dir = await _resolveDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedDir = dir;
    return dir;
  }

  Future<Directory> _resolveDirectory() async {
    try {
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          return Directory('$home/Library/Application Support/$namespace');
        }
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          return Directory('$home/.local/share/$namespace');
        }
      } else if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          return Directory('$appData\\$namespace');
        }
      }
    } catch (_) {
      // Fall back to a temp directory below.
    }

    return Directory('${Directory.systemTemp.path}/$namespace');
  }
}

StorageBackend createPlatformStorageBackend({required String namespace}) {
  return _IoStorageBackend(namespace: namespace);
}
