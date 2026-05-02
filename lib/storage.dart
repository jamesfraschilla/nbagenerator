import 'storage_backend.dart';

/// Provides simple key/value text persistence across platforms.
class AppStorage {
  AppStorage._();

  static final AppStorage instance = AppStorage._();

  final StorageBackend _backend =
      createStorageBackend(namespace: 'ClutchScenarios');

  Future<bool> exists(String name) => _backend.exists(name);

  Future<String?> readText(String name) => _backend.readText(name);

  Future<void> writeText(String name, String value) =>
      _backend.writeText(name, value);
}
