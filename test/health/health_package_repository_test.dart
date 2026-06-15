import 'package:cairn/src/health/health_gateway.dart';
import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/health/health_package_repository.dart';
import 'package:cairn/src/health/health_sample.dart';
import 'package:cairn/src/health/health_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [HealthGateway] for testing the repository's orchestration without
/// the platform plugin.
class _FakeGateway implements HealthGateway {
  _FakeGateway({
    this.permissions = const {},
    this.samples = const {},
    this.denyRead = const {},
  });

  final Map<HealthMetric, bool?> permissions;
  final Map<HealthMetric, List<HealthSample>> samples;
  final Set<HealthMetric> denyRead;

  int configureCalls = 0;
  Set<HealthMetric>? requestedMetrics;

  @override
  Future<void> configure() async {
    configureCalls++;
  }

  @override
  Future<void> requestReadAuthorization(Set<HealthMetric> metrics) async {
    requestedMetrics = metrics;
  }

  @override
  Future<bool?> hasReadPermission(HealthMetric metric) async =>
      permissions.containsKey(metric) ? permissions[metric] : true;

  @override
  Future<List<HealthSample>> readSamples({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) async {
    if (denyRead.contains(metric)) {
      throw PlatformException(code: 'denied');
    }
    return samples[metric] ?? const [];
  }
}

void main() {
  final t = DateTime(2026, 6, 14, 8);

  HealthSource source(String name) => HealthSource(
    name: name,
    platform: HealthPlatform.googleHealthConnect,
    recordingMethod: RecordingMethodKind.automatic,
  );

  test('requestAuthorization returns only the granted metrics', () async {
    final gateway = _FakeGateway(
      permissions: {
        HealthMetric.heartRate: true,
        HealthMetric.steps: false,
        HealthMetric.weight: null, // iOS-style: unknown => assume granted
      },
    );
    final repo = HealthPackageRepository(gateway: gateway);

    final granted = await repo.requestAuthorization({
      HealthMetric.heartRate,
      HealthMetric.steps,
      HealthMetric.weight,
    });

    expect(granted, {HealthMetric.heartRate, HealthMetric.weight});
    expect(gateway.requestedMetrics, {
      HealthMetric.heartRate,
      HealthMetric.steps,
      HealthMetric.weight,
    });
  });

  test('configure runs once across authorization and reads', () async {
    final gateway = _FakeGateway();
    final repo = HealthPackageRepository(gateway: gateway);

    await repo.requestAuthorization({HealthMetric.heartRate});
    await repo.readSamples(metric: HealthMetric.heartRate, start: t, end: t);
    await repo.readSamples(metric: HealthMetric.steps, start: t, end: t);

    expect(gateway.configureCalls, 1);
  });

  test('readSamples deduplicates competing same-window readings', () async {
    ScalarSample hr(double value, String sourceName) => ScalarSample(
      metric: HealthMetric.heartRate,
      value: value,
      unit: 'count/min',
      start: t,
      end: t,
      source: source(sourceName),
    );
    final gateway = _FakeGateway(
      samples: {
        HealthMetric.heartRate: [hr(70, 'Pixel Phone'), hr(68, 'Galaxy Watch')],
      },
    );
    final repo = HealthPackageRepository(gateway: gateway);

    final samples = await repo.readSamples(
      metric: HealthMetric.heartRate,
      start: t,
      end: t,
    );

    expect(samples, hasLength(1));
    expect(samples.single.source.name, 'Galaxy Watch');
  });

  test('a denied read degrades to an empty list, never throws', () async {
    final gateway = _FakeGateway(denyRead: {HealthMetric.heartRate});
    final repo = HealthPackageRepository(gateway: gateway);

    final samples = await repo.readSamples(
      metric: HealthMetric.heartRate,
      start: t,
      end: t,
    );

    expect(samples, isEmpty);
  });
}
