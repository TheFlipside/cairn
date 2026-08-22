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
  /// Whether the OS health store is present and usable on this device.
  ///
  /// `false` only on Android, when Health Connect is missing or its provider
  /// needs an update. Every read then fails, so the UI reports it as its own
  /// outcome rather than as a generic read error.
  Future<bool> isAvailable();

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

/// Thrown when the OS health store cannot be reached at all — on Android, when
/// Health Connect is absent or its provider needs an update.
///
/// Distinct from a failed *read*: nothing is wrong with the request, the store
/// simply is not there, and the user has to act on the device before any read
/// can work.
class HealthStoreUnavailableException implements Exception {
  /// Creates the exception.
  const HealthStoreUnavailableException();

  @override
  String toString() =>
      'HealthStoreUnavailableException: '
      'the OS health store is not available on this device';
}
