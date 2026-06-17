import 'package:cairn/src/format/locale_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats decimals with the locale separator', () {
    expect(formatDecimal(72.5, locale: 'en'), '72.5');
    expect(formatDecimal(72.5, locale: 'de'), '72,5');
  });

  test('respects the requested fraction digits', () {
    expect(formatDecimal(22, locale: 'en'), '22.0');
    expect(formatDecimal(22.456, locale: 'en', fractionDigits: 2), '22.46');
  });

  test('groups integers per locale', () {
    expect(formatInteger(1234, locale: 'en'), '1,234');
    expect(formatInteger(1234, locale: 'de'), '1.234');
  });

  test('rounds before formatting integers', () {
    expect(formatInteger(1234.7, locale: 'en'), '1,235');
  });
}
