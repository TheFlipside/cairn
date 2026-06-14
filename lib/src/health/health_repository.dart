import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/health/health_sample.dart';

/// Read-only access to the OS health store (Apple HealthKit / Android Health
/// Connect).
///
/// Cairn only ever reads; it never writes back to the health store
/// (DESIGN.md §2, §4.1). This interface isolates the native capability so it
/// can be mocked in tests (DESIGN.md §13). Implementations wrap the `health`
/// package.
abstract interface class HealthRepository {
  /// Requests read authorisation for [metrics] and returns the subset granted.
  ///
  /// Callers must handle partial grants gracefully and must not depend on a
  /// single boolean: iOS deliberately hides read-authorisation status, so
  /// design around data presence instead (DESIGN.md §4.2).
  Future<Set<HealthMetric>> requestAuthorization(Set<HealthMetric> metrics);

  /// Reads samples of [metric] recorded within the half-open window
  /// `[start, end)`.
  Future<List<HealthSample>> readSamples({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  });
}
