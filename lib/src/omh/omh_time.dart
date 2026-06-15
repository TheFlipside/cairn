/// Formats [dateTime] as an OMH / RFC-3339 timestamp carrying an explicit
/// local UTC offset, e.g. `2026-06-14T08:30:55+02:00` (DESIGN.md §5.2).
///
/// Cairn stores the device's local offset rather than bare UTC so the per-day
/// shard boundary (§5.3) stays on the user's calendar day. Dart's
/// [DateTime.toIso8601String] omits the offset for local `DateTime`s, so this
/// builds the representation explicitly, to whole-second precision.
String omhDateTime(DateTime dateTime) {
  final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final abs = offset.abs();
  final date = '${_pad(local.year, 4)}-${_pad(local.month)}-${_pad(local.day)}';
  final time =
      '${_pad(local.hour)}:${_pad(local.minute)}:${_pad(local.second)}';
  final zone = '${_pad(abs.inHours)}:${_pad(abs.inMinutes.remainder(60))}';
  return '${date}T$time$sign$zone';
}

String _pad(int value, [int width = 2]) => value.toString().padLeft(width, '0');
