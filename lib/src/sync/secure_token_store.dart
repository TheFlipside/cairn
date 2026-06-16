import 'package:cairn/src/sync/nextcloud_credentials.dart';

/// Stores the Nextcloud [NextcloudCredentials] — whose app password is never
/// the user's main password — in OS secure storage: Keychain on iOS, Keystore
/// on Android (DESIGN.md §6).
///
/// The whole credential (server, login name, app password) is persisted as one
/// atomic unit: the app password is the secret, and its server+user addressing
/// is kept alongside it so a stored token is always usable. Isolated behind an
/// interface so the platform capability is mockable in tests (DESIGN.md §13).
abstract interface class SecureTokenStore {
  /// Persists [credentials] in secure storage, replacing any existing entry.
  Future<void> writeCredentials(NextcloudCredentials credentials);

  /// Reads the stored credentials, or `null` if none are stored (or the stored
  /// value is unreadable).
  Future<NextcloudCredentials?> readCredentials();

  /// Deletes the stored credentials (e.g. on disconnect).
  Future<void> deleteCredentials();
}
