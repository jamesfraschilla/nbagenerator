import 'dart:io';

/// Provides access to an application-specific directory for storing data.
class AppStorage {
  AppStorage._();

  static final AppStorage instance = AppStorage._();

  Directory? _cachedDir;

  /// Returns the root storage directory for the app, creating it on demand.
  Future<Directory> root() async {
    final cached = _cachedDir;
    if (cached != null) return cached;

    final Directory dir = await _resolveDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cachedDir = dir;
    return dir;
  }

  /// Resolves a file within the app directory.
  Future<File> file(String name) async {
    final dir = await root();
    return File('${dir.path}/$name');
  }

  Future<Directory> _resolveDirectory() async {
    const folderName = 'ClutchScenarios';

    try {
      if (Platform.isMacOS) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          return Directory('$home/Library/Application Support/$folderName');
        }
      } else if (Platform.isLinux) {
        final home = Platform.environment['HOME'];
        if (home != null && home.isNotEmpty) {
          return Directory('$home/.local/share/$folderName');
        }
      } else if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null && appData.isNotEmpty) {
          return Directory('$appData\\$folderName');
        }
      }
    } catch (_) {
      // Fall back to a temp directory below.
    }

    return Directory('${Directory.systemTemp.path}/$folderName');
  }
}
