/// The health measures Cairn maps in v1 (DESIGN.md §5.2).
///
/// Each value corresponds to a single Open mHealth / IEEE 1752.1 schema and a
/// dedicated on-disk shard (`/Cairn/<metric>/<year>/<date>.jsonl`).
enum HealthMetric {
  /// Heart rate, in beats per minute.
  heartRate,

  /// Cumulative step count.
  steps,

  /// Sleep episodes and their duration.
  sleep,

  /// Physical activity and workouts.
  activity,

  /// Body weight, in kilograms.
  weight,
}
