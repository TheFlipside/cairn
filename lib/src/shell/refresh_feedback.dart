import 'package:cairn/l10n/app_localizations.dart';
import 'package:cairn/src/shell/cairn_services.dart';
import 'package:cairn/src/shell/sync_error_feedback.dart';

/// Maps a [RefreshResult] to a localised, user-facing message — or `null` when
/// the refresh fully succeeded and nothing needs to be shown.
extension RefreshResultMessage on RefreshResult {
  /// The snackbar text for this result in the active locale, or `null` on
  /// success. A `null` [cause] yields a generic message — only a translated,
  /// typed error is ever interpolated into the user-facing text.
  String? localizedMessage(AppLocalizations l10n) => switch (status) {
    // Success is silent on this (snackbar) path — Home/Sleep/on-open show no
    // message even when a push ran; the report is surfaced only in Settings.
    RefreshStatus.ok => null,
    RefreshStatus.readFailed => l10n.refreshReadFailed,
    RefreshStatus.healthUnavailable => l10n.refreshHealthUnavailable,
    RefreshStatus.syncFailed =>
      cause == null
          ? l10n.refreshSyncFailedGeneric
          : l10n.refreshSyncFailed(cause!.localizedMessage(l10n)),
  };
}
