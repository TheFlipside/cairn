import 'package:cairn/l10n/app_localizations.dart';
import 'package:cairn/src/shell/cairn_services.dart';

/// Maps a [RefreshResult] to a localised, user-facing message — or `null` when
/// the refresh fully succeeded and nothing needs to be shown.
extension RefreshResultMessage on RefreshResult {
  /// The snackbar text for this result in the active locale, or `null` on
  /// success. A `null` [detail] yields a generic message — only a controlled,
  /// typed error message is ever interpolated into the user-facing text.
  String? localizedMessage(AppLocalizations l10n) => switch (status) {
    RefreshStatus.ok => null,
    RefreshStatus.readFailed => l10n.refreshReadFailed,
    RefreshStatus.syncFailed =>
      detail == null
          ? l10n.refreshSyncFailedGeneric
          : l10n.refreshSyncFailed(detail!),
  };
}
