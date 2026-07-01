import 'dart:io';

import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/health/health_repository.dart';
import 'package:cairn/src/health/health_sample.dart';
import 'package:cairn/src/health/health_source.dart';
import 'package:cairn/src/storage/health_ingest_service.dart';
import 'package:cairn/src/storage/jsonl_omh_file_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records read windows and returns canned samples per metric.
class _FakeRepository implements HealthRepository {
  _FakeRepository(this.samples);

  final Map<HealthMetric, List<HealthSample>> samples;
  final List<({HealthMetric metric, DateTime start, DateTime end})> reads = [];

  @override
  Future<Set<HealthMetric>> requestAuthorization(
    Set<HealthMetric> metrics,
  ) async => metrics;

  @override
  Future<List<HealthSample>> readSamples({
    required HealthMetric metric,
    required DateTime start,
    required DateTime end,
  }) async {
    reads.add((metric: metric, start: start, end: end));
    // Behave like the real store: only return samples whose effective time is
    // within the requested window, so window logic is actually exercised.
    return (samples[metric] ?? const [])
        .where((s) => !s.start.isBefore(start) && !s.start.isAfter(end))
        .toList();
  }
}

void main() {
  late Directory tempRoot;
  late JsonlOmhFileStore store;

  const source = HealthSource(
    name: 'Watch',
    platform: HealthPlatform.googleHealthConnect,
    recordingMethod: RecordingMethodKind.automatic,
  );

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('cairn_ingest_test');
    store = JsonlOmhFileStore(root: tempRoot);
  });
  tearDown(() => tempRoot.deleteSync(recursive: true));

  Map<String, Object?> asMap(Object? value) => value! as Map<String, Object?>;

  test('persists datapoints and advances the anchor', () async {
    final t = DateTime(2026, 6, 14, 8);
    final repo = _FakeRepository({
      HealthMetric.heartRate: [
        ScalarSample(
          metric: HealthMetric.heartRate,
          value: 62,
          unit: 'count/min',
          start: t,
          end: t,
          source: source,
        ),
      ],
    });
    final now = DateTime(2026, 6, 14, 12);
    final ingest = HealthIngestService(
      repository: repo,
      store: store,
      clock: () => now,
    );

    final results = await ingest.ingest({HealthMetric.heartRate});
    expect(results.single.dataPointCount, 1);

    final onDisk = await store.readRange(
      metric: HealthMetric.heartRate,
      from: t,
      to: now,
    );
    expect(onDisk, hasLength(1));
    final anchor = await store.lastSyncAnchor(HealthMetric.heartRate);
    expect(anchor!.isAtSameMomentAs(now), isTrue);
  });

  test('groups datapoints into per-day shards', () async {
    final d1 = DateTime(2026, 6, 13, 23);
    final d2 = DateTime(2026, 6, 14, 1);
    final repo = _FakeRepository({
      HealthMetric.weight: [
        ScalarSample(
          metric: HealthMetric.weight,
          value: 70,
          unit: 'kg',
          start: d1,
          end: d1,
          source: source,
        ),
        ScalarSample(
          metric: HealthMetric.weight,
          value: 71,
          unit: 'kg',
          start: d2,
          end: d2,
          source: source,
        ),
      ],
    });
    final ingest = HealthIngestService(
      repository: repo,
      store: store,
      clock: () => DateTime(2026, 6, 14, 12),
    );
    await ingest.ingest({HealthMetric.weight});

    final root = tempRoot.path;
    expect(File('$root/weight/2026/2026-06-13.jsonl').existsSync(), isTrue);
    expect(File('$root/weight/2026/2026-06-14.jsonl').existsSync(), isTrue);
  });

  test(
    'sleep writes both stage and episode lines into the sleep shard',
    () async {
      final night = DateTime(2026, 6, 13, 23);
      final repo = _FakeRepository({
        HealthMetric.sleep: [
          SleepSegmentSample(
            start: night,
            end: night.add(const Duration(minutes: 60)),
            source: source,
            stage: SleepStage.deep,
          ),
          SleepSegmentSample(
            start: night.add(const Duration(minutes: 60)),
            end: night.add(const Duration(minutes: 120)),
            source: source,
            stage: SleepStage.rem,
          ),
        ],
      });
      final ingest = HealthIngestService(
        repository: repo,
        store: store,
        clock: () => DateTime(2026, 6, 14, 12),
      );
      await ingest.ingest({HealthMetric.sleep});

      final read = await store.readRange(
        metric: HealthMetric.sleep,
        from: night,
        to: DateTime(2026, 6, 14),
      );
      final names = read
          .map((dp) => asMap(asMap(dp['header'])['schema_id'])['name'])
          .toSet();
      expect(names, containsAll(<String>['sleep-stage', 'sleep-episode']));
    },
  );

  test(
    'a second run re-reads the reconcile window, not just the anchor',
    () async {
      final repo = _FakeRepository({HealthMetric.steps: const []});
      final firstNow = DateTime(2026, 6, 14, 12);
      await HealthIngestService(
        repository: repo,
        store: store,
        clock: () => firstNow,
      ).ingest({HealthMetric.steps});
      // First run has no anchor → window starts ~30 days back.
      expect(
        repo.reads.last.start.isBefore(
          firstNow.subtract(const Duration(days: 29)),
        ),
        isTrue,
      );

      final secondNow = DateTime(2026, 6, 15, 12);
      await HealthIngestService(
        repository: repo,
        store: store,
        clock: () => secondNow,
      ).ingest({HealthMetric.steps});
      // Second run goes back the reconcile window (well before the anchor) so
      // backdated entries are still caught.
      expect(
        repo.reads.last.start.isAtSameMomentAs(
          secondNow.subtract(const Duration(days: 14)),
        ),
        isTrue,
      );
      expect(repo.reads.last.start.isBefore(firstNow), isTrue);
    },
  );

  test('imports a backdated reading on a later run', () async {
    final repo = _FakeRepository({HealthMetric.weight: []});
    await HealthIngestService(
      repository: repo,
      store: store,
      clock: () => DateTime(2026, 6, 14, 12),
    ).ingest({HealthMetric.weight});

    // User logs a weight dated yesterday — before the anchor, within the
    // reconcile window.
    final backdated = DateTime(2026, 6, 13, 8);
    repo.samples[HealthMetric.weight] = [
      ScalarSample(
        metric: HealthMetric.weight,
        value: 80,
        unit: 'kg',
        start: backdated,
        end: backdated,
        source: source,
      ),
    ];
    final results = await HealthIngestService(
      repository: repo,
      store: store,
      clock: () => DateTime(2026, 6, 14, 18),
    ).ingest({HealthMetric.weight});

    expect(results.single.dataPointCount, 1);
    final onDisk = await store.readRange(
      metric: HealthMetric.weight,
      from: backdated,
      to: DateTime(2026, 6, 14, 18),
    );
    expect(onDisk, hasLength(1));
  });

  test(
    're-ingesting sleep does not duplicate stage or episode lines',
    () async {
      final night = DateTime(2026, 6, 13, 23);
      final repo = _FakeRepository({
        HealthMetric.sleep: [
          SleepSegmentSample(
            start: night,
            end: night.add(const Duration(minutes: 60)),
            source: source,
            stage: SleepStage.deep,
          ),
        ],
      });
      final first = await HealthIngestService(
        repository: repo,
        store: store,
        clock: () => DateTime(2026, 6, 14, 12),
      ).ingest({HealthMetric.sleep});
      expect(first.single.dataPointCount, 2); // one stage + one episode line

      final second = await HealthIngestService(
        repository: repo,
        store: store,
        clock: () => DateTime(2026, 6, 14, 18),
      ).ingest({HealthMetric.sleep});
      expect(second.single.dataPointCount, 0); // neither line re-written

      final onDisk = await store.readRange(
        metric: HealthMetric.sleep,
        from: night,
        to: DateTime(2026, 6, 14, 18),
      );
      expect(onDisk, hasLength(2));
    },
  );

  test('re-ingesting the same data does not duplicate it', () async {
    final t = DateTime(2026, 6, 14, 8);
    final repo = _FakeRepository({
      HealthMetric.weight: [
        ScalarSample(
          metric: HealthMetric.weight,
          value: 70,
          unit: 'kg',
          start: t,
          end: t,
          source: source,
        ),
      ],
    });
    final first = await HealthIngestService(
      repository: repo,
      store: store,
      clock: () => DateTime(2026, 6, 14, 12),
    ).ingest({HealthMetric.weight});
    expect(first.single.dataPointCount, 1);

    // Same reading is still inside the next run's window — must not re-write.
    final second = await HealthIngestService(
      repository: repo,
      store: store,
      clock: () => DateTime(2026, 6, 14, 18),
    ).ingest({HealthMetric.weight});
    expect(second.single.dataPointCount, 0);

    final onDisk = await store.readRange(
      metric: HealthMetric.weight,
      from: t,
      to: DateTime(2026, 6, 14, 18),
    );
    expect(onDisk, hasLength(1));
  });

  test('a cumulative daily total is compacted, not accumulated', () async {
    // Samsung Health reports the day's steps as one whole-day record whose
    // value grows through the day; each refresh reads the current total.
    final dayStart = DateTime(2026, 6, 14);
    final dayEnd = DateTime(2026, 6, 14, 23, 59, 59);
    final repo = _FakeRepository({HealthMetric.steps: []});

    Future<void> ingestTotal(double value, DateTime at) async {
      repo.samples[HealthMetric.steps] = [
        ScalarSample(
          metric: HealthMetric.steps,
          value: value,
          unit: 'steps',
          start: dayStart,
          end: dayEnd,
          source: source,
        ),
      ];
      await HealthIngestService(
        repository: repo,
        store: store,
        clock: () => at,
      ).ingest({HealthMetric.steps});
    }

    await ingestTotal(14, DateTime(2026, 6, 14, 6));
    await ingestTotal(5034, DateTime(2026, 6, 14, 9));
    await ingestTotal(7050, DateTime(2026, 6, 14, 14));

    final onDisk = await store.readRange(
      metric: HealthMetric.steps,
      from: dayStart,
      to: dayEnd,
    );
    // The same whole-day window collapses to a single, current record.
    expect(onDisk, hasLength(1));
    final body = asMap(onDisk.single['body']);
    expect(asMap(body['step_count'])['value'], 7050.0);
  });

  test('distinct step windows are not compacted together', () async {
    // A source that writes per-interval deltas (distinct windows) must keep
    // every record — only same-window re-reports collapse.
    final t0 = DateTime(2026, 6, 14, 6);
    final t1 = t0.add(const Duration(minutes: 1));
    final t2 = t1.add(const Duration(minutes: 1));
    final repo = _FakeRepository({
      HealthMetric.steps: [
        ScalarSample(
          metric: HealthMetric.steps,
          value: 50,
          unit: 'steps',
          start: t0,
          end: t1,
          source: source,
        ),
        ScalarSample(
          metric: HealthMetric.steps,
          value: 60,
          unit: 'steps',
          start: t1,
          end: t2,
          source: source,
        ),
      ],
    });
    await HealthIngestService(
      repository: repo,
      store: store,
      clock: () => DateTime(2026, 6, 14, 12),
    ).ingest({HealthMetric.steps});

    final onDisk = await store.readRange(
      metric: HealthMetric.steps,
      from: t0,
      to: DateTime(2026, 6, 14, 12),
    );
    expect(onDisk, hasLength(2));
  });

  test('a malformed shard line blocks compaction (no data loss)', () async {
    final dayStart = DateTime(2026, 6, 14);
    final dayEnd = DateTime(2026, 6, 14, 23, 59, 59);

    Future<void> ingestTotal(double value, DateTime at) async {
      final repo = _FakeRepository({
        HealthMetric.steps: [
          ScalarSample(
            metric: HealthMetric.steps,
            value: value,
            unit: 'steps',
            start: dayStart,
            end: dayEnd,
            source: source,
          ),
        ],
      });
      await HealthIngestService(
        repository: repo,
        store: store,
        clock: () => at,
      ).ingest({HealthMetric.steps});
    }

    await ingestTotal(14, DateTime(2026, 6, 14, 6));

    // Simulate a torn append (a crash mid-write) leaving a malformed line.
    final shard = File('${tempRoot.path}/steps/2026/2026-06-14.jsonl')
      ..writeAsStringSync('{"torn":\n', mode: FileMode.append);

    // A new total supersedes 14, but the malformed line must block the rewrite,
    // so the shard is appended to (not compacted) and the torn line survives.
    await ingestTotal(7050, DateTime(2026, 6, 14, 14));

    expect(shard.readAsStringSync(), contains('{"torn":'));
    final values = (await store.readRange(
      metric: HealthMetric.steps,
      from: dayStart,
      to: dayEnd,
    )).map((dp) => asMap(asMap(dp['body'])['step_count'])['value']).toSet();
    // Compaction skipped: 14 was NOT dropped, and 7050 was appended.
    expect(values, containsAll(<double>[14, 7050]));
  });
}
