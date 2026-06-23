import 'package:cairn/src/query/night_sleep.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reconcileNights returns a mutable empty list for no stages', () {
    // Regression: the empty result used to be a `const []`. Callers sort the
    // result in place (health_query_service.lastNNights), and sorting a const
    // list throws "Cannot modify an unmodifiable list" — the crash a fresh,
    // no-data install hit. Assert the empty result is genuinely sortable.
    final nights = reconcileNights(const [], const []);
    expect(nights, isEmpty);
    expect(
      () => nights.sort((a, b) => a.start.compareTo(b.start)),
      returnsNormally,
    );
  });
}
