import 'dart:typed_data';

/// Remote Nextcloud target for the `/Cairn/` file tree, spoken over WebDAV on
/// top of a permissive HTTP client (DESIGN.md §6).
///
/// Implemented directly rather than via the AGPL-licensed `nextcloud` Dart
/// client, to keep the app under the MIT licence.
abstract interface class NextcloudSyncTarget {
  /// Uploads [bytes] to [remotePath] (WebDAV `PUT`), creating parent
  /// collections as needed.
  Future<void> putFile({
    required String remotePath,
    required Uint8List bytes,
  });

  /// Lists the file paths directly under [remoteDir] (WebDAV `PROPFIND`).
  Future<List<String>> list(String remoteDir);

  /// Downloads the file at [remotePath] (WebDAV `GET`).
  Future<Uint8List> getFile(String remotePath);
}
