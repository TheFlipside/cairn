import 'package:cairn/src/health/health_metric.dart';
import 'package:cairn/src/health/health_sample.dart';

/// Maps raw [HealthSample]s to Open mHealth / IEEE 1752.1 datapoints.
///
/// A datapoint is represented as a JSON-serialisable map (one object per line
/// in the `.jsonl` shards). Emitted datapoints must validate against the OMH
/// schema library in tests — the format is the product's durability guarantee
/// (DESIGN.md §5, §13).
abstract interface class OmhMapper {
  /// Converts [sample] into an Open mHealth datapoint object.
  Map<String, Object?> toDataPoint(HealthSample sample);

  /// The OMH / IEEE 1752.1 schema id Cairn emits for [metric]
  /// (e.g. `omh:heart-rate`). Measures without a standard schema use the
  /// `cairn` namespace (DESIGN.md §5.2).
  String schemaIdFor(HealthMetric metric);
}
