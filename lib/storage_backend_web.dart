// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'storage_backend.dart';

class _WebStorageBackend implements StorageBackend {
  _WebStorageBackend({required this.namespace});

  final String namespace;

  @override
  Future<bool> exists(String key) async {
    return html.window.localStorage.containsKey(_scopedKey(key));
  }

  @override
  Future<String?> readText(String key) async {
    return html.window.localStorage[_scopedKey(key)];
  }

  @override
  Future<void> writeText(String key, String value) async {
    html.window.localStorage[_scopedKey(key)] = value;
  }

  String _scopedKey(String key) => '$namespace.$key';
}

StorageBackend createPlatformStorageBackend({required String namespace}) {
  return _WebStorageBackend(namespace: namespace);
}
