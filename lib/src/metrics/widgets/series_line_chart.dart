import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// One plotted point: a value at an instant.
typedef SeriesPoint = ({DateTime at, double value});

/// A simple time-ordered line chart for a scalar series (weight, daily-average
/// heart rate). Points are plotted by index (evenly spaced) with date labels at
/// the ends, which keeps sparse series readable. Degrades to a placeholder when
/// there is nothing meaningful to draw.
class SeriesLineChart extends StatelessWidget {
  /// Creates a line chart over [points] (assumed oldest-first). [emptyLabel] is
  /// shown when there are fewer than two points.
  const SeriesLineChart({
    required this.points,
    required this.emptyLabel,
    super.key,
  });

  /// The series to plot, oldest-first.
  final List<SeriesPoint> points;

  /// Placeholder text when the series cannot be charted.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) {
      return _placeholder(theme);
    }
    final values = points.map((p) => p.value).toList();
    var min = values.first;
    var max = values.first;
    for (final v in values) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    // Pad the Y range so a flat or near-flat series still renders a visible
    // line rather than collapsing onto an axis edge.
    final pad = (max - min).abs() < 0.001 ? 1.0 : (max - min) * 0.1;
    final spots = <FlSpot>[
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].value),
    ];

    String label(DateTime t) =>
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (points.length - 1).toDouble(),
          minY: min - pad,
          maxY: max + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 40),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                // Span the full range so fl_chart only auto-ticks the
                // endpoints; the guard below suppresses any others.
                interval: (points.length - 1).toDouble(),
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i != 0 && i != points.length - 1) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label(points[i].at),
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: theme.colorScheme.primary,
              dotData: FlDotData(show: points.length <= 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => SizedBox(
    height: 180,
    child: Center(
      child: Text(emptyLabel, style: theme.textTheme.bodyMedium),
    ),
  );
}
