import 'package:cairn/l10n/app_localizations.dart';

/// Formats a [duration] compactly using the active locale's unit words, e.g.
/// `7h 20m` / `45m` under `en`, `7 Std. 20 Min.` / `45 Min.` under `de`.
String formatHoursMinutes(Duration duration, AppLocalizations l10n) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return l10n.durationMinutes(minutes);
  return l10n.durationHoursMinutes(hours, minutes);
}
