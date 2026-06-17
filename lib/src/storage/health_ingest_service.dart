import 'dart:convert';

import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/health/health_repository.dart';
import 'package:cairn/src/health/health_sample.dart';
import 'package:cairn/src/health/sleep_aggregator.dart';
import 'package:cairn/src/omh/default_omh_mapper.dart';
import 'package:cairn/src/omh/omh_mapper.dart';
import 'package:cairn/src/storage/omh_file_store.dart';
import 'package:flutter/foundation.dart';

/// How many datapoints were persisted for one metric in an ingest run.
@immutable
class IngestResult {
  /// Creates an ingest result.
  const IngestResult({required this.metric, required this.dataPointCount});

  /// The metric ingested.
  final HealthMetric metric;

  /// Number of OMH datapoints written to disk.
  final int dataPointCount;
}

/// The local write path (DESIGN.md §9, minus Nextcloud): read health for the
/// window, map to OMH, persist into the [OmhFileStore], and advance the
/// per-metric sync anchor.
///
/// Each run re-reads a trailing [reconcileLookback] window — not just
/// `[anchor, now]` — so **backdated or late-arriving** entries are still
/// imported (e.g. a workout logged this morning for an earlier time, after a
/// prior sync already advanced the anchor past it). The basic `health` API can
/// only query by *effective* time, so this overlap is how late writes are
/// caught; doing so reliably for backdating *beyond* the window needs
/// when-written change tokens (a native plugin — DESIGN.md §4.3, Phase 8).
///
/// Appends are **idempotent**: a datapoint already on disk — matched by schema
/// + provenance + body, ignoring its random header `id`/`creation_date_time`
/// (which differ on every re-ingest) — is not written again, so the reconcile
/// overlap never duplicates data.
final class HealthIngestService {
  /// Creates an ingest service. [mapper], [aggregator], [clock],
  /// [initialLookback] and [reconcileLookback] are injectable for tests.
  HealthIngestService({
    required this.repository,
    required this.store,
    OmhMapper? mapper,
    this.aggregator = const SleepEpisodeAggregator(),
    DateTime Function()? clock,
    this.initialLookback = const Duration(days: 30),
    this.reconcileLookback = const Duration(days: 14),
  }) : assert(
         reconcileLookback <= initialLookback,
         'reconcileLookback must not exceed the first-run initialLookback',
       ),
       _mapper = mapper ?? DefaultOmhMapper(),
       _now = clock ?? DateTime.now;

  /// The health-store reader (Phase 1).
  final HealthRepository repository;

  /// The local file store datapoints are persisted into.
  final OmhFileStore store;

  /// Aggregates sleep-stage segments into nightly episodes.
  final SleepEpisodeAggregator aggregator;

  /// First-run look-back used when a metric has no sync anchor yet.
  final Duration initialLookback;

  /// Trailing window re-read on every run (in addition to anything past the
  /// anchor) so backdated/late entries whose effective time precedes the
  /// anchor are still imported.
  final Duration reconcileLookback;

  final OmhMapper _mapper;
  final DateTime Function() _now;

  /// Ingests each metric in [metrics] over `[start, now]`, where `start` is
  /// the earlier of the sync anchor and `now - reconcileLookback` (or `now -
  /// initialLookback` on first run), then advances the anchor. Returns the
  /// per-metric count of **newly written** datapoints.
  Future<List<IngestResult>> ingest(Set<HealthMetric> metrics) async {
    final results = <IngestResult>[];
    final now = _now();
    for (final metric in metrics) {
      final anchor = await store.lastSyncAnchor(metric);
      final start = _windowStart(anchor, now);
      final samples = await repository.readSamples(
        metric: metric,
        start: start,
        end: now,
      );
      final count = await _persist(metric, samples);
      await store.setSyncAnchor(metric, now);
      results.add(IngestResult(metric: metric, dataPointCount: count));
    }
    return results;
  }

  /// First run (no anchor) reads the full [initialLookback]; later runs read
  /// from the earlier of the anchor and `now - reconcileLookback`, so a
  /// sync gap is covered by the anchor and recent backdating by the window.
  DateTime _windowStart(DateTime? anchor, DateTime now) {
    if (anchor == null) return now.subtract(initialLookback);
    final reconcileStart = now.subtract(reconcileLookback);
    return anchor.isBefore(reconcileStart) ? anchor : reconcileStart;
  }

  Future<int> _persist(HealthMetric metric, List<HealthSample> samples) async {
    // Datapoints grouped by the local calendar day of the source reading, so
    // each lands in the right per-day shard (DESIGN.md §5.3).
    final byDay = <DateTime, List<Map<String, Object?>>>{};
    void add(DateTime day, Map<String, Object?> dataPoint) =>
        (byDay[_dateOnly(day)] ??= []).add(dataPoint);

    for (final sample in samples) {
      add(sample.start, _mapper.toDataPoint(sample));
    }
    // Sleep also gets the additive nightly episode rollup.
    if (metric == HealthMetric.sleep) {
      final segments = samples.whereType<SleepSegmentSample>().toList();
      for (final episode in aggregator.aggregate(segments)) {
        // Keyed on the episode's start (start-of-night) so it co-locates with
        // the night's stage segments in the same shard where possible.
        add(episode.start, _mapper.sleepEpisodeToDataPoint(episode));
      }
    }

    var count = 0;
    for (final entry in byDay.entries) {
      // Idempotent append: skip datapoints already on disk for this day so the
      // reconcile-window overlap doesn't duplicate (DESIGN.md §4.3).
      final existing = await store.readRange(
        metric: metric,
        from: entry.key,
        to: entry.key,
      );
      final seen = {for (final dp in existing) _contentKey(dp)};
      final fresh = <Map<String, Object?>>[];
      for (final dataPoint in entry.value) {
        if (seen.add(_contentKey(dataPoint))) fresh.add(dataPoint);
      }
      if (fresh.isEmpty) continue;
      await store.append(metric: metric, day: entry.key, dataPoints: fresh);
      count += fresh.length;
    }
    return count;
  }

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
}

/// A stable identity for a datapoint that ignores the random header `id` and
/// the ingest-time `creation_date_time`, so the same reading re-read from the
/// health store matches what is already on disk (DESIGN.md §4.3).
///
/// Correctness depends on the kept fields being stable across re-reads: the
/// body (values + `effective_time_frame`) and `acquisition_provenance`
/// (`source_name`, `modality`, and `source_creation_date_time`, which is the
/// reading's effective time, not a wall-clock). The same health-store record
/// re-read yields identical JSON, so its key matches and it is not re-written.
String _contentKey(Map<String, Object?> dataPoint) {
  final header = dataPoint['header'];
  final headerMap = header is Map<String, Object?>
      ? header
      : const <String, Object?>{};
  return jsonEncode({
    'schema': headerMap['schema_id'],
    'provenance': headerMap['acquisition_provenance'],
    'body': dataPoint['body'],
  });
}
