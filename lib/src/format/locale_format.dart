/// Locale-aware formatting of user-facing numbers.
///
/// The active UI locale decides the decimal and grouping separators, so 72.5
/// renders as `72,5` under `de` and `72.5` under `en`. Pass the BuildContext's
/// locale tag (e.g. `Localizations.localeOf(context).toLanguageTag()`).
library;

import 'package:intl/intl.dart';

/// Formats [value] with [fractionDigits] fixed fraction digits in [locale].
String formatDecimal(
  double value, {
  required String locale,
  int fractionDigits = 1,
}) => NumberFormat.decimalPatternDigits(
  locale: locale,
  decimalDigits: fractionDigits,
).format(value);

/// Formats [value] (rounded) as a grouped integer in [locale]
/// (e.g. `1,234` under `en`, `1.234` under `de`).
String formatInteger(num value, {required String locale}) =>
    NumberFormat.decimalPattern(locale).format(value.round());
