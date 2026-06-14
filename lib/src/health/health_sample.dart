import 'package:cairn/src/health/health_metric.dart';
import 'package:flutter/foundation.dart';

/// A single immutable reading taken from the OS health store, before it is
/// normalised into an Open mHealth datapoint.
@immutable
class HealthSample {
  /// Creates a health sample.
  const HealthSample({
    required this.metric,
    required this.value,
    required this.unit,
    required this.start,
    required this.end,
    required this.sourceName,
  });

  /// The measure this sample belongs to.
  final HealthMetric metric;

  /// Numeric value of the reading, expressed in [unit].
  final double value;

  /// Unit taken verbatim from the source schema (e.g. `beats/min`, `kg`).
  final String unit;

  /// Inclusive start of the reading's effective time frame.
  final DateTime start;

  /// Exclusive end of the reading's effective time frame.
  final DateTime end;

  /// Origin of the reading (phone, watch or vendor app), used for provenance
  /// and source-priority deduplication (DESIGN.md §4.3).
  final String sourceName;
}
