import 'package:cairn/l10n/app_localizations.dart';
import 'package:cairn/src/sync/nextcloud_sync_target.dart';

/// Turns a [NextcloudSyncException] into text the user can read in their own
/// language.
///
/// The exception's `message` is an English diagnostic aimed at logs and bug
/// reports; showing it would leave the German UI half-translated and could leak
/// a path or host into the interface. The translated sentence comes from
/// [NextcloudSyncException.kind] instead, with the HTTP status appended when
/// the server gave one — a number is language-neutral and is the single most
/// useful thing a user can quote when asking for help.
extension SyncErrorMessage on NextcloudSyncException {
  /// This failure, described in the active locale.
  String localizedMessage(AppLocalizations l10n) {
    final status = statusCode;
    final text = _text(l10n, status);
    // 404 already reads as "not found"; repeating the status adds nothing.
    if (status == null || kind == SyncErrorKind.notFound) return text;
    return l10n.syncErrorWithStatus(text, status);
  }

  String _text(AppLocalizations l10n, int? status) {
    // An expired or revoked app password surfaces as a plain HTTP status on
    // every endpoint, so it is recognised here rather than at each throw site.
    if (status == 401 || status == 403) return l10n.syncErrorUnauthorized;
    return switch (kind) {
      SyncErrorKind.hostNotHttps => l10n.syncErrorHostNotHttps,
      SyncErrorKind.network => l10n.syncErrorNetwork,
      SyncErrorKind.timedOut => l10n.syncErrorTimedOut,
      SyncErrorKind.loginFailed => l10n.syncErrorLoginFailed,
      SyncErrorKind.malformedResponse => l10n.syncErrorMalformedResponse,
      SyncErrorKind.serverRejected => l10n.syncErrorServerRejected,
      SyncErrorKind.notFound => l10n.syncErrorNotFound,
      SyncErrorKind.tooLarge => l10n.syncErrorTooLarge,
      SyncErrorKind.credentialStorage => l10n.syncErrorCredentialStorage,
      SyncErrorKind.unknown => l10n.syncErrorUnknown,
    };
  }
}
