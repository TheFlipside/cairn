import 'package:cairn/src/health/health_gateway.dart';
import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/health/health_repository.dart';
import 'package:cairn/src/health/health_sample.dart';
import 'package:cairn/src/health/source_dedup.dart';
import 'package:flutter/services.dart';

/// [HealthRepository] implemented over a [HealthGateway] (DESIGN.md §4).
///
/// Cairn only reads. Authorisation is requested once and resolved per-metric so
/// partial grants degrade gracefully (§4.2): a metric counts as granted when
/// the OS says so, or — on iOS, which hides read status — optimistically, with
/// presence proven by reading. A read the OS denies yields an empty list rather
/// than throwing, so one denied type never breaks a batch. Competing
/// same-window readings are collapsed by source priority (§4.3).
final class HealthPackageRepository implements HealthRepository {
  /// Creates a repository. [gateway] and [deduplicator] are injectable; the
  /// gateway defaults to the real `health`-package implementation.
  HealthPackageRepository({
    HealthGateway? gateway,
    SourcePriorityDeduplicator deduplicator =
        const SourcePriorityDeduplicator(),
  }) : _gateway = gateway ?? HealthPackageGateway(),
       _dedup = deduplicator;

  final HealthGateway _gateway;
  final SourcePriorityDeduplicator _dedup;
  Future<void>? _configuring;

  @override
  Future<Set<HealthMetric>> requestAuthorization(
    Set<HealthMetric> metrics,
  ) async {
    await _ensureConfigured();
    await _gateway.requestReadAuthorization(metrics);

    final granted = <HealthMetric>{};
    for (final metric in metrics) {
      final status = await _gateway.hasReadPermission(metric);
      // null (iOS) → assume granted; presence is proven by a later read.
      if (status ?? true) granted.add(metric);
    }
    return granted;
  }

  @override
  Future<List<HealthSample>> readSamples({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) async {
    await _ensureConfigured();
    try {
      final samples = await _gateway.readSamples(
        metric: metric,
        start: start,
        end: end,
      );
      return _dedup.deduplicate(samples);
    } on PlatformException {
      return <HealthSample>[];
    }
  }

  // Configures the gateway at most once. Concurrent callers share the single
  // in-flight future, avoiding a double-configure race.
  Future<void> _ensureConfigured() => _configuring ??= _gateway.configure();
}
