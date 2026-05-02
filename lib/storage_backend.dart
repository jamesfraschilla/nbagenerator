import 'storage_backend_stub.dart'
    if (dart.library.html) 'storage_backend_web.dart'
    if (dart.library.io) 'storage_backend_io.dart';

abstract class StorageBackend {
  Future<bool> exists(String key);

  Future<String?> readText(String key);

  Future<void> writeText(String key, String value);
}

StorageBackend createStorageBackend({required String namespace}) =>
    createPlatformStorageBackend(namespace: namespace);
