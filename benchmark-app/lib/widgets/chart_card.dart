import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/benchmark_data.dart';
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
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fieldName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildChart()),
            const SizedBox(height: 8),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    final lines = <LineChartBarData>[];

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
      lines.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.2,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }

    if (lines.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    // Compute dynamic Y range from actual data
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

    // Add 10% padding
    final range = maxY - minY;
    final paddedMin = (minY - range * 0.1).clamp(0, double.infinity);
    final paddedMax = maxY + range * 0.1;

    return LineChart(
      LineChartData(
        minY: range == 0 ? 0.0 : paddedMin.toDouble(),
        maxY: range == 0 ? maxY * 1.1 : paddedMax,
        lineBarsData: lines,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: null,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Text(
                  _formatNumber(value),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) {
                  return const SizedBox.shrink();
                }
                return Text(
                  '${value.toInt()}s',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
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
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            maxContentWidth: 300,
            getTooltipColor: (_) => const Color(0xF0222222),
            getTooltipItems: (touchedSpots) {
              // Sort by value descending
              final sorted = List<LineBarSpot>.from(touchedSpots)
                ..sort((a, b) => b.y.compareTo(a.y));
              return sorted.map((spot) {
                final name = selectedServices.elementAt(spot.barIndex);
                final color = spot.bar.color ?? Colors.white;
                return LineTooltipItem(
                  '● $name: ${_formatNumber(spot.y)}',
                  TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: selectedServices.where((s) => services.containsKey(s)).map((name) {
        final color = ServiceColors.getColor(name);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(name, style: const TextStyle(fontSize: 11)),
          ],
        );
      }).toList(),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}
