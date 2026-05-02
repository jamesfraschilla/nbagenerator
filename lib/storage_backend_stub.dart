import 'storage_backend.dart';

StorageBackend createPlatformStorageBackend({required String namespace}) {
  throw UnsupportedError('Storage backend is not available on this platform.');
}
