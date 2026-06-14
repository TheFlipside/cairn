import 'package:flutter/foundation.dart';

/// A pending Nextcloud Login Flow v2 session (DESIGN.md §6).
@immutable
class LoginFlowSession {
  /// Creates a login-flow session.
  const LoginFlowSession({required this.loginUrl, required this.pollToken});

  /// URL the user opens in a webview to authorise Cairn.
  final Uri loginUrl;

  /// Opaque token used to poll for the resulting app password.
  final String pollToken;
}

/// Obtains a Nextcloud app password via Login Flow v2, so Cairn never handles
/// the user's main password (DESIGN.md §6).
abstract interface class NextcloudAuth {
  /// Begins Login Flow v2 against [host] and returns the session used to drive
  /// the webview and polling.
  Future<LoginFlowSession> begin(Uri host);

  /// Polls [session]; completes with the app password once the user has
  /// authorised, or `null` while the flow is still pending.
  Future<String?> poll(LoginFlowSession session);
}
