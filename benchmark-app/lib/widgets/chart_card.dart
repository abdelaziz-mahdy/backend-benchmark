import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/benchmark_data.dart';
import '../providers/benchmark_provider.dart';
import '../utils/colors.dart';
import '../utils/data_smoother.dart';

class ChartCard extends StatelessWidget {
  final String fieldName;
  final Map<String, BenchmarkService> services;
  final Set<String> selectedServices;

  const ChartCard({
    super.key,
    required this.fieldName,
    required this.services,
    required this.selectedServices,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fieldName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFC9D1D9),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final lines = <LineChartBarData>[];
    final serviceNames = <String>[];

    for (final name in selectedServices) {
      final service = services[name];
      if (service == null) continue;

      final smoothed = smooth(service.data, fieldName);
      final spots = <FlSpot>[];

      for (var i = 0; i < service.data.length; i++) {
        final x = service.data[i].timestamp;
        final y = smoothed[i];
        if (!y.isNaN && !y.isInfinite) {
          spots.add(FlSpot(x, y));
        }
      }

      if (spots.isEmpty) continue;

      final color = ServiceColors.getColor(name);
      final isNoDb = name.contains('no_db_test');
      lines.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: color,
          barWidth: isNoDb ? 1.5 : 2,
          dashArray: isNoDb ? [6, 3] : null,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: color.withValues(alpha: 0.04),
          ),
        ),
      );
      serviceNames.add(name);
    }

    if (lines.isEmpty) {
      return const Center(
        child: Text(
          'No data',
          style: TextStyle(color: Color(0xFF484F58), fontSize: 12),
        ),
      );
    }

    // Compute dynamic Y range
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final line in lines) {
      for (final spot in line.spots) {
        if (spot.y < minY) minY = spot.y;
        if (spot.y > maxY) maxY = spot.y;
      }
    }
    if (minY == double.infinity) minY = 0;
    if (maxY == double.negativeInfinity) maxY = 1;

    final range = maxY - minY;
    final paddedMin = (minY - range * 0.05).clamp(0.0, double.infinity);
    final paddedMax = maxY + range * 0.05;

    return LineChart(
      LineChartData(
        minY: range == 0 ? 0.0 : paddedMin,
        maxY: range == 0 ? maxY * 1.1 : paddedMax,
        lineBarsData: lines,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: const Color(0xFF21262D), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    _formatNumber(value),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF484F58),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${value.toInt()}s',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF484F58),
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: Color(0xFF21262D)),
            left: BorderSide(color: Color(0xFF21262D)),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 220,
            getTooltipColor: (_) => const Color(0xF0161B22),
            getTooltipItems: (touchedSpots) {
              // Rank spots by value descending to find top 5
              final ranked = List<LineBarSpot>.from(touchedSpots)
                ..sort((a, b) => b.y.compareTo(a.y));
              final top5Indices = ranked.take(5).map((s) => s.barIndex).toSet();
              final hiddenCount = touchedSpots.length - top5Indices.length;

              // Must return exactly one item per touchedSpot (null to hide)
              return touchedSpots.asMap().entries.map((entry) {
                final spot = entry.value;
                if (!top5Indices.contains(spot.barIndex)) return null;

                final idx = spot.barIndex;
                final name = idx < serviceNames.length
                    ? BenchmarkProvider.frameworkName(serviceNames[idx])
                    : '?';
                final color = spot.bar.color ?? Colors.white;

                // Append "+N more" to the last visible item
                final isLastVisible =
                    spot.barIndex == ranked.take(5).last.barIndex;
                final suffix = (isLastVisible && hiddenCount > 0)
                    ? '\n+$hiddenCount more'
                    : '';

                return LineTooltipItem(
                  '$name: ${_formatNumber(spot.y)}$suffix',
                  TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
