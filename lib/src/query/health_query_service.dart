import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/health/health_source.dart';
import 'package:cairn/src/health/source_dedup.dart';
import 'package:cairn/src/query/display_readings.dart';
import 'package:cairn/src/query/metric_series.dart';
import 'package:cairn/src/query/night_sleep.dart';
import 'package:cairn/src/query/omh_reading_parser.dart';
import 'package:cairn/src/storage/omh_file_store.dart';

/// Read-path query API the dashboard uses over the local OMH cache
/// (DESIGN.md §9, read path A). An interface so screens can be tested with a
/// fake (real file I/O can't complete under the widget tester's fake-async).
abstract interface class HealthQueryService {
  /// The most recent scalar reading for [metric], or `null`.
  Future<ScalarReading?> latestScalar(HealthMetric metric);

  /// Today's total step count (source-deduplicated), or `null`.
  Future<double?> todayStepTotal();

  /// The most recent night of sleep, or `null`.
  Future<NightSleep?> lastNight();

  /// The last [n] nights of sleep, most-recent first.
  Future<List<NightSleep>> lastNNights(int n);

  /// Raw scalar readings for [metric] over the last [days], oldest-first.
  Future<List<ScalarReading>> scalarSeries(HealthMetric metric, {int days});

  /// Per-day total step counts over the last [days], oldest-first. Days with
  /// no data are included with a zero value so charts show the gap.
  Future<List<DailyValue>> dailySteps({int days});

  /// Per-day min / mean / max heart rate over the last [days], oldest-first.
  /// Days with no readings are omitted.
  Future<List<DailyStat>> dailyHeartRate({int days});

  /// Recent workouts over the last [days], most-recent-first.
  Future<List<WorkoutReading>> recentWorkouts({int days});
}

/// [HealthQueryService] backed by an [OmhFileStore]. Pure over the injected
/// store, so it is fully testable with a temp-dir store.
final class OmhHealthQueryService implements HealthQueryService {
  /// Creates a query service. [clock] and [lookback] are injectable; [lookback]
  /// bounds how far "latest"-style queries scan before giving up.
  OmhHealthQueryService({
    required this.store,
    DateTime Function()? clock,
    this.lookback = const Duration(days: 90),
  }) : _now = clock ?? DateTime.now;

  /// The cache this service reads.
  final OmhFileStore store;

  /// Maximum look-back for "latest" queries.
  final Duration lookback;

  final DateTime Function() _now;

  @override
  Future<ScalarReading?> latestScalar(HealthMetric metric) async {
    final today = _dateOnly(_now());
    for (var i = 0; i <= lookback.inDays; i++) {
      final day = today.subtract(Duration(days: i));
      final maps = await store.readRange(metric: metric, from: day, to: day);
      final readings = maps
          .map(parseScalar)
          .whereType<ScalarReading>()
          .toList();
      if (readings.isNotEmpty) {
        readings.sort((a, b) => b.at.compareTo(a.at));
        return readings.first;
      }
    }
    return null;
  }

  @override
  Future<double?> todayStepTotal() async {
    final today = _dateOnly(_now());
    final readings = (await store.readRange(
      metric: HealthMetric.steps,
      from: today,
      to: today,
    )).map(parseInterval).whereType<IntervalReading>().toList();
    if (readings.isEmpty) return null;
    return _dedupIntervals(
      readings,
    ).fold<double>(0, (sum, r) => sum + r.value);
  }

  @override
  Future<NightSleep?> lastNight() async {
    final nights = await lastNNights(1);
    return nights.isEmpty ? null : nights.first;
  }

  @override
  Future<List<NightSleep>> lastNNights(int n) async {
    final to = _dateOnly(_now());
    final from = to.subtract(Duration(days: n + 1));
    final maps = await store.readRange(
      metric: HealthMetric.sleep,
      from: from,
      to: to,
    );
    final stages = <SleepStageReading>[];
    final episodes = <SleepEpisodeReading>[];
    for (final map in maps) {
      switch (omhSchemaName(map)) {
        case 'sleep-stage':
          final reading = parseSleepStage(map);
          if (reading != null) stages.add(reading);
        case 'sleep-episode':
          final reading = parseSleepEpisode(map);
          if (reading != null) episodes.add(reading);
      }
    }
    final nights = reconcileNights(stages, episodes)
      ..sort((a, b) => b.start.compareTo(a.start));
    return nights.take(n).toList();
  }

  @override
  Future<List<ScalarReading>> scalarSeries(
    HealthMetric metric, {
    int days = 90,
  }) async {
    final to = _dateOnly(_now());
    // `days - 1`: the window is inclusive of today, so N days spans
    // [today-(N-1), today] (matches dailyHeartRate / dailySteps).
    final from = to.subtract(Duration(days: days - 1));
    final maps = await store.readRange(metric: metric, from: from, to: to);
    return maps.map(parseScalar).whereType<ScalarReading>().toList()
      ..sort((a, b) => a.at.compareTo(b.at));
  }

  @override
  Future<List<DailyValue>> dailySteps({int days = 14}) async {
    final to = _dateOnly(_now());
    final series = <DailyValue>[];
    // Read per day so deduplication is within-day (matching todayStepTotal),
    // and include empty days as zero so the trend chart shows the gap.
    for (var i = days - 1; i >= 0; i--) {
      final day = to.subtract(Duration(days: i));
      final readings = (await store.readRange(
        metric: HealthMetric.steps,
        from: day,
        to: day,
      )).map(parseInterval).whereType<IntervalReading>().toList();
      final total = readings.isEmpty
          ? 0.0
          : _dedupIntervals(readings).fold<double>(0, (s, r) => s + r.value);
      series.add(DailyValue(day: day, value: total));
    }
    return series;
  }

  @override
  Future<List<DailyStat>> dailyHeartRate({int days = 14}) async {
    final to = _dateOnly(_now());
    final from = to.subtract(Duration(days: days - 1));
    final maps = await store.readRange(
      metric: HealthMetric.heartRate,
      from: from,
      to: to,
    );
    final byDay = <DateTime, List<double>>{};
    for (final map in maps) {
      final reading = parseScalar(map);
      if (reading == null) continue;
      (byDay[_dateOnly(reading.at)] ??= []).add(reading.value);
    }
    final stats = byDay.entries.map((entry) {
      final values = entry.value;
      return DailyStat(
        day: entry.key,
        min: values.reduce((a, b) => a < b ? a : b),
        max: values.reduce((a, b) => a > b ? a : b),
        mean: values.reduce((a, b) => a + b) / values.length,
        count: values.length,
      );
    }).toList()..sort((a, b) => a.day.compareTo(b.day));
    return stats;
  }

  @override
  Future<List<WorkoutReading>> recentWorkouts({int days = 30}) async {
    final to = _dateOnly(_now());
    // `days - 1`: inclusive of today (see scalarSeries).
    final from = to.subtract(Duration(days: days - 1));
    final maps = await store.readRange(
      metric: HealthMetric.activity,
      from: from,
      to: to,
    );
    return maps.map(parseWorkout).whereType<WorkoutReading>().toList()
      ..sort((a, b) => b.start.compareTo(a.start));
  }

  /// Keeps the preferred source per `(start,end)` step interval before summing.
  List<IntervalReading> _dedupIntervals(List<IntervalReading> readings) {
    const policy = SourcePriorityPolicy.defaults();
    final best = <String, IntervalReading>{};
    for (final r in readings) {
      final key = '${_seconds(r.start)}|${_seconds(r.end)}';
      final current = best[key];
      if (current == null || _rank(policy, r) < _rank(policy, current)) {
        best[key] = r;
      }
    }
    return best.values.toList();
  }

  int _rank(SourcePriorityPolicy policy, IntervalReading r) => policy.rank(
    HealthMetric.steps,
    _readingHealthSource(r.source),
  );

  // Recording method is all the steps policy needs beyond the name; platform is
  // unused on the read path (not stored in OMH).
  HealthSource _readingHealthSource(ReadingSource? source) => HealthSource(
    name: source?.name ?? 'unknown',
    platform: HealthPlatform.googleHealthConnect,
    recordingMethod: source?.modality == 'self-reported'
        ? RecordingMethodKind.manual
        : RecordingMethodKind.automatic,
  );

  static DateTime _dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);
  static int _seconds(DateTime t) => t.toUtc().millisecondsSinceEpoch ~/ 1000;
}
