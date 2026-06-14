/// Stores the Nextcloud app password — never the user's main password — in OS
/// secure storage: Keychain on iOS, Keystore on Android (DESIGN.md §6).
///
/// Isolated behind an interface so the platform capability can be mocked in
/// tests (DESIGN.md §13).
abstract interface class SecureTokenStore {
  /// Persists the Nextcloud app [token] in secure storage.
  Future<void> writeAppToken(String token);

  /// Reads the stored Nextcloud app token, or `null` if none is stored.
  Future<String?> readAppToken();

  /// Deletes the stored Nextcloud app token (e.g. on disconnect).
  Future<void> deleteAppToken();
}
