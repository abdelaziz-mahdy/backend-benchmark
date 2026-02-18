import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/benchmark_data.dart';
import '../providers/benchmark_provider.dart';
import '../utils/colors.dart';
import '../utils/data_smoother.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        if (provider.data == null) {
          return const Center(
            child: Text(
              'No data loaded',
              style: TextStyle(color: kTextMuted, fontSize: 14),
            ),
          );
        }

        final selectedName = provider.selectedDetailService;
        final service =
            selectedName != null ? provider.data![selectedName] : null;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildFrameworkSelector(context, provider),
                  if (service == null) ...[
                    const SizedBox(height: 120),
                    _buildEmptyState(),
                  ] else ...[
                    const SizedBox(height: 20),
                    _buildSummaryCards(service),
                    const SizedBox(height: 20),
                    _buildTimeSeriesGrid(service, selectedName!),
                    const SizedBox(height: 20),
                    _buildPercentileChart(service),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Framework Selector
  // ---------------------------------------------------------------------------

  Widget _buildFrameworkSelector(
      BuildContext context, BenchmarkProvider provider) {
    final services = <String>[];
    switch (provider.testTypeFilter) {
      case TestTypeFilter.db:
        services.addAll(provider.dbServices);
        break;
      case TestTypeFilter.noDb:
        services.addAll(provider.noDbServices);
        break;
      case TestTypeFilter.all:
        services.addAll(provider.data!.keys);
        break;
    }
    services.sort();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: (provider.selectedDetailService != null &&
                    services.contains(provider.selectedDetailService))
                ? provider.selectedDetailService
                : null,
            hint: const Text(
              'Select a framework...',
              style: TextStyle(color: kTextMuted, fontSize: 14),
            ),
            dropdownColor: kCardBg,
            icon:
                const Icon(Icons.expand_more, color: kTextMuted, size: 20),
            isExpanded: true,
            style: const TextStyle(color: kTextPrimary, fontSize: 14),
            items: services.map((name) {
              final color = ServiceColors.getColor(name);
              return DropdownMenuItem(
                value: name,
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(BenchmarkProvider.frameworkName(name)),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                provider.selectDetailService(value);
              }
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 56, color: kTextDim),
          SizedBox(height: 16),
          Text(
            'Select a framework to view details',
            style: TextStyle(color: kTextMuted, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Summary Stat Cards
  // ---------------------------------------------------------------------------

  Widget _buildSummaryCards(BenchmarkService service) {
    final stats = <_StatItem>[
      _StatItem(
        label: 'Requests/s',
        value: service.summary['Average Requests/s'],
      ),
      _StatItem(
        label: 'Avg Response',
        value: service.summary['Average Response Time (ms)'],
        unit: 'ms',
      ),
      _StatItem(
        label: 'P50',
        value: service.summary['Average Response Time 50% (ms)'],
        unit: 'ms',
      ),
      _StatItem(
        label: 'P99',
        value: service.summary['Average Response Time 99% (ms)'],
        unit: 'ms',
      ),
      _StatItem(
        label: 'Failures/s',
        value: service.summary['Average Failures/s'],
      ),
      _StatItem(
        label: 'CPU %',
        value: service.summary['Average Server CPU Usage'],
        unit: '%',
      ),
      _StatItem(
        label: 'DB CPU %',
        value: service.summary['Average Database CPU Usage'],
        unit: '%',
      ),
      _StatItem(
        label: 'Memory',
        value: service.summary['Average Server Memory (MB)'],
        unit: 'MB',
      ),
      _StatItem(
        label: 'CPU Eff',
        value: service.summary['CPU Efficiency'],
        unit: 'req/s/%',
      ),
      _StatItem(
        label: 'Mem Eff',
        value: service.summary['Memory Efficiency'],
        unit: 'req/s/MB',
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: stats.map((s) => _buildStatCard(s)).toList(),
    );
  }

  Widget _buildStatCard(_StatItem stat) {
    final value = stat.value;
    String formatted;
    if (value == null) {
      formatted = 'N/A';
    } else {
      formatted = formatNumber(value);
      if (stat.unit != null) formatted += ' ${stat.unit}';
    }

    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stat.label,
            style: const TextStyle(
              fontSize: 11,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatted,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Time Series Charts (2x2 Grid)
  // ---------------------------------------------------------------------------

  Widget _buildTimeSeriesGrid(BenchmarkService service, String serviceName) {
    final charts = <_ChartDef>[
      _ChartDef(title: 'Requests/s', field: 'Requests/s'),
      _ChartDef(title: 'Response Time', field: 'Response Time'),
      _ChartDef(title: 'CPU Usage', field: 'benchmark_cpu_usage'),
      _ChartDef(title: 'Memory Usage', field: 'benchmark_mem_usage_mb'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 2 : 1;
        final childAspectRatio = constraints.maxWidth > 700 ? 1.8 : 1.6;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: charts.length,
          itemBuilder: (context, index) {
            final def = charts[index];
            return _buildSingleLineChart(
              title: def.title,
              service: service,
              serviceName: serviceName,
              field: def.field,
            );
          },
        );
      },
    );
  }

  Widget _buildSingleLineChart({
    required String title,
    required BenchmarkService service,
    required String serviceName,
    required String field,
  }) {
    final smoothed = smooth(service.data, field);
    final spots = <FlSpot>[];

    for (var i = 0; i < service.data.length; i++) {
      final x = service.data[i].timestamp;
      final y = smoothed[i];
      if (!y.isNaN && !y.isInfinite) {
        spots.add(FlSpot(x, y));
      }
    }

    final color = ServiceColors.getColor(serviceName);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: spots.isEmpty
                ? const Center(
                    child: Text(
                      'No data',
                      style: TextStyle(color: kTextDim, fontSize: 12),
                    ),
                  )
                : _buildLineChart(spots, color),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(List<FlSpot> spots, Color color) {
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final spot in spots) {
      if (spot.y < minY) minY = spot.y;
      if (spot.y > maxY) maxY = spot.y;
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
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.08),
            ),
          ),
        ],
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: kGridLine, strokeWidth: 1),
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
                    formatNumber(value),
                    style: const TextStyle(fontSize: 10, color: kTextDim),
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
                    style: const TextStyle(fontSize: 10, color: kTextDim),
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
            bottom: BorderSide(color: kGridLine),
            left: BorderSide(color: kGridLine),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => kCardBg.withValues(alpha: 0.94),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  formatNumber(spot.y),
                  TextStyle(
                    color: spot.bar.color ?? Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 4: Percentile Distribution Bar Chart
  // ---------------------------------------------------------------------------

  Widget _buildPercentileChart(BenchmarkService service) {
    final lastPoint = service.data.isNotEmpty ? service.data.last : null;

    // Gather percentile values: prefer summary, fall back to last data point
    final percentiles = <_PercentileEntry>[
      _PercentileEntry(
        label: 'P50',
        value: service.summary['Average Response Time 50% (ms)'] ??
            lastPoint?.p50,
      ),
      _PercentileEntry(
        label: 'P66',
        value: lastPoint?.p66,
      ),
      _PercentileEntry(
        label: 'P75',
        value: service.summary['Average Response Time 75% (ms)'] ??
            lastPoint?.p75,
      ),
      _PercentileEntry(
        label: 'P80',
        value: lastPoint?.p80,
      ),
      _PercentileEntry(
        label: 'P90',
        value: lastPoint?.p90,
      ),
      _PercentileEntry(
        label: 'P95',
        value: lastPoint?.p95,
      ),
      _PercentileEntry(
        label: 'P98',
        value: lastPoint?.p98,
      ),
      _PercentileEntry(
        label: 'P99',
        value: service.summary['Average Response Time 99% (ms)'] ??
            lastPoint?.p99,
      ),
      _PercentileEntry(
        label: 'P99.9',
        value: lastPoint?.p999,
      ),
    ];

    // Filter out nulls
    final validPercentiles =
        percentiles.where((p) => p.value != null && p.value! > 0).toList();

    if (validPercentiles.isEmpty) {
      return const SizedBox.shrink();
    }

    double maxVal = 0;
    for (final p in validPercentiles) {
      if (p.value! > maxVal) maxVal = p.value!;
    }

    return SizedBox(
      width: double.infinity,
      child: Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Response Time Percentiles',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal * 1.15,
                barGroups: List.generate(validPercentiles.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: validPercentiles[i].value!,
                        color: kBlue.withValues(alpha: 0.7),
                        width: 28,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(4),
                        ),
                      ),
                    ],
                    showingTooltipIndicators: [],
                  );
                }),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: kGridLine, strokeWidth: 1),
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
                            '${formatNumber(value)} ms',
                            style:
                                const TextStyle(fontSize: 10, color: kTextDim),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= validPercentiles.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            validPercentiles[idx].label,
                            style:
                                const TextStyle(fontSize: 10, color: kTextMuted),
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
                    bottom: BorderSide(color: kGridLine),
                    left: BorderSide(color: kGridLine),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipColor: (_) => kCardBg.withValues(alpha: 0.94),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = validPercentiles[group.x].label;
                      return BarTooltipItem(
                        '$label: ${formatNumber(rod.toY)} ms',
                        const TextStyle(
                          color: kBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private data classes
// ---------------------------------------------------------------------------

class _StatItem {
  final String label;
  final double? value;
  final String? unit;

  const _StatItem({required this.label, this.value, this.unit});
}

class _ChartDef {
  final String title;
  final String field;

  const _ChartDef({required this.title, required this.field});
}

class _PercentileEntry {
  final String label;
  final double? value;

  const _PercentileEntry({required this.label, this.value});
}
