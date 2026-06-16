import 'dart:convert';

import 'package:cairn/src/sync/nextcloud_credentials.dart';
import 'package:cairn/src/sync/secure_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure-storage key the credential bundle is stored under.
const String _credentialsKey = 'nextcloud_credentials';

/// [SecureTokenStore] backed by `flutter_secure_storage` (Keychain on iOS,
/// Keystore-backed encrypted storage on Android) (DESIGN.md §6).
final class FlutterSecureTokenStore implements SecureTokenStore {
  /// Creates a store. [storage] is injectable for tests; the default uses the
  /// platform-secure backend (Keychain / Android Keystore-backed ciphers).
  FlutterSecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> writeCredentials(NextcloudCredentials credentials) =>
      _storage.write(
        key: _credentialsKey,
        value: jsonEncode(credentials.toJson()),
      );

  @override
  Future<NextcloudCredentials?> readCredentials() async {
    final raw = await _storage.read(key: _credentialsKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return NextcloudCredentials.fromJson(decoded);
      }
    } on FormatException {
      // Corrupt or non-https stored value → treat as not connected.
    }
    return null;
  }

  @override
  Future<void> deleteCredentials() => _storage.delete(key: _credentialsKey);
}
