import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/benchmark_data.dart';
import '../providers/benchmark_provider.dart';
import '../utils/colors.dart';

// Theme constants
const _kCard = Color(0xFF161B22);
const _kBorder = Color(0xFF30363D);
const _kText = Color(0xFFE6EDF3);
const _kSecondary = Color(0xFFC9D1D9);
const _kMuted = Color(0xFF8B949E);
const _kDim = Color(0xFF484F58);
const _kGreen = Color(0xFF3FB950);

/// Metrics used for the radar and comparison charts.
class _MetricDef {
  final String label;
  final String summaryKey;
  final bool inverted; // true = lower real value is better

  const _MetricDef(this.label, this.summaryKey, {this.inverted = false});
}

const _radarMetrics = [
  _MetricDef('Requests/s', 'Average Requests/s'),
  _MetricDef('Avg Response', 'Average Response Time (ms)', inverted: true),
  _MetricDef('P99 Response', 'Average Response Time 99% (ms)', inverted: true),
  _MetricDef('Server CPU', 'Average Server CPU Usage', inverted: true),
  _MetricDef('DB CPU', 'Average Database CPU Usage', inverted: true),
];

const _tableMetrics = [
  _MetricDef('Requests/s', 'Average Requests/s'),
  _MetricDef('Avg Response (ms)', 'Average Response Time (ms)', inverted: true),
  _MetricDef('P50 Response (ms)', 'Average Response Time 50% (ms)',
      inverted: true),
  _MetricDef('P75 Response (ms)', 'Average Response Time 75% (ms)',
      inverted: true),
  _MetricDef('P99 Response (ms)', 'Average Response Time 99% (ms)',
      inverted: true),
  _MetricDef('Server CPU %', 'Average Server CPU Usage', inverted: true),
  _MetricDef('DB CPU %', 'Average Database CPU Usage', inverted: true),
  _MetricDef('Failures/s', 'Average Failures/s', inverted: true),
];

class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        final allServices = _filteredServiceNames(provider);
        final selected = provider.compareServices
            .where((s) => allServices.contains(s))
            .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(title: 'Select Frameworks'),
              const SizedBox(height: 8),
              _FrameworkSelector(
                allServices: allServices,
                selected: provider.compareServices,
                onToggle: provider.toggleCompareService,
              ),
              const SizedBox(height: 24),
              if (selected.length < 2)
                _EmptyState()
              else ...[
                _SectionTitle(title: 'Performance Radar'),
                const SizedBox(height: 8),
                _RadarSection(
                  selected: selected,
                  data: provider.data!,
                ),
                const SizedBox(height: 24),
                _SectionTitle(title: 'Metric Comparison'),
                const SizedBox(height: 8),
                _BarComparisonSection(
                  selected: selected,
                  data: provider.data!,
                ),
                const SizedBox(height: 24),
                _SectionTitle(title: 'Detailed Comparison'),
                const SizedBox(height: 8),
                _ComparisonTable(
                  selected: selected,
                  data: provider.data!,
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  List<String> _filteredServiceNames(BenchmarkProvider provider) {
    switch (provider.testTypeFilter) {
      case TestTypeFilter.db:
        return provider.dbServices;
      case TestTypeFilter.noDb:
        return provider.noDbServices;
      case TestTypeFilter.all:
        return provider.data?.keys.toList() ?? [];
    }
  }
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _kText,
        letterSpacing: -0.3,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.compare_arrows, size: 48, color: _kBorder),
            SizedBox(height: 12),
            Text(
              'Select at least 2 frameworks to compare',
              style: TextStyle(color: _kMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Framework selector chips
// ---------------------------------------------------------------------------

class _FrameworkSelector extends StatelessWidget {
  final List<String> allServices;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _FrameworkSelector({
    required this.allServices,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select 2\u20134 frameworks to compare',
              style: const TextStyle(color: _kDim, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allServices.map((name) {
                final isSelected = selected.contains(name);
                final color = ServiceColors.getColor(name);
                final label = BenchmarkProvider.frameworkName(name);
                final atMax = selected.length >= 4 && !isSelected;

                return GestureDetector(
                  onTap: atMax ? null : () => onToggle(name),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : _kBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isSelected ? color : _kDim,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? _kText : _kMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Radar chart section
// ---------------------------------------------------------------------------

class _RadarSection extends StatelessWidget {
  final List<String> selected;
  final Map<String, BenchmarkService> data;

  const _RadarSection({required this.selected, required this.data});

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeRadar(selected, data);
    // Collect raw values for the value table
    final rawValues = <String, List<double>>{};
    for (final service in selected) {
      rawValues[service] = _radarMetrics
          .map((m) => data[service]?.summary[m.summaryKey] ?? 0)
          .toList();
    }

    return Card(
      color: _kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: selected.map((name) {
                final color = ServiceColors.getColor(name);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      BenchmarkProvider.frameworkName(name),
                      style: const TextStyle(color: _kSecondary, fontSize: 12),
                    ),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Radar chart
            SizedBox(
              height: 350,
              child: RadarChart(
                RadarChartData(
                  radarShape: RadarShape.polygon,
                  dataSets: normalized.entries.map((entry) {
                    final color = ServiceColors.getColor(entry.key);
                    return RadarDataSet(
                      dataEntries: entry.value
                          .map((v) => RadarEntry(value: v))
                          .toList(),
                      borderColor: color,
                      fillColor: color.withValues(alpha: 0.15),
                      borderWidth: 2,
                      entryRadius: 3,
                    );
                  }).toList(),
                  radarBackgroundColor: Colors.transparent,
                  borderData: FlBorderData(show: false),
                  radarBorderData:
                      const BorderSide(color: _kBorder, width: 0.5),
                  tickBorderData:
                      const BorderSide(color: _kBorder, width: 0.5),
                  gridBorderData:
                      const BorderSide(color: _kBorder, width: 0.5),
                  tickCount: 4,
                  ticksTextStyle: const TextStyle(
                    color: Colors.transparent,
                    fontSize: 0,
                  ),
                  titlePositionPercentageOffset: 0.2,
                  titleTextStyle: const TextStyle(
                    color: _kMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  getTitle: (index, angle) {
                    return RadarChartTitle(
                      text: _radarMetrics[index].label,
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Radar value table — shows actual values for each axis
            _RadarValueTable(
              selected: selected,
              rawValues: rawValues,
            ),
            const SizedBox(height: 8),
            Text(
              'Outer edge = best performance. Values normalized across all frameworks.',
              style: const TextStyle(color: _kDim, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  /// Normalizes radar values across ALL frameworks (not just selected)
  /// so the chart accurately represents relative performance.
  Map<String, List<double>> _normalizeRadar(
      List<String> services, Map<String, BenchmarkService> data) {
    final result = <String, List<double>>{};

    for (final service in services) {
      result[service] = List.filled(_radarMetrics.length, 0.0);
    }

    for (var i = 0; i < _radarMetrics.length; i++) {
      final metric = _radarMetrics[i];

      // Collect values from ALL frameworks for global normalization
      final allValues = <double>[];
      for (final entry in data.entries) {
        final v = entry.value.summary[metric.summaryKey] ?? 0;
        if (v > 0) allValues.add(v);
      }

      if (allValues.isEmpty) continue;

      final globalMin = allValues.reduce(math.min);
      final globalMax = allValues.reduce(math.max);
      final range = globalMax - globalMin;

      for (final service in services) {
        final value = data[service]?.summary[metric.summaryKey] ?? 0;
        double normalized;
        if (range == 0) {
          normalized = 1.0;
        } else {
          normalized = (value - globalMin) / range;
          if (metric.inverted) {
            normalized = 1.0 - normalized;
          }
        }
        result[service]![i] = normalized.clamp(0.05, 1.0);
      }
    }

    return result;
  }
}

/// Shows actual raw values for each radar axis per framework.
class _RadarValueTable extends StatelessWidget {
  final List<String> selected;
  final Map<String, List<double>> rawValues;

  const _RadarValueTable({
    required this.selected,
    required this.rawValues,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 28,
        columnSpacing: 16,
        headingRowColor: WidgetStateProperty.all(
          _kBorder.withValues(alpha: 0.2),
        ),
        dataRowColor: WidgetStateProperty.all(Colors.transparent),
        border: TableBorder(
          horizontalInside: BorderSide(color: _kBorder.withValues(alpha: 0.3)),
        ),
        columns: [
          const DataColumn(
            label: Text('Metric',
                style: TextStyle(
                    color: _kMuted, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          ...selected.map((name) {
            final color = ServiceColors.getColor(name);
            return DataColumn(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    BenchmarkProvider.frameworkName(name),
                    style: const TextStyle(
                        color: _kSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
        ],
        rows: List.generate(_radarMetrics.length, (i) {
          final metric = _radarMetrics[i];
          // Find best value across selected for highlighting
          final vals = selected.map((s) => rawValues[s]![i]).toList();
          final best = metric.inverted
              ? vals.where((v) => v > 0).fold<double>(double.infinity, math.min)
              : vals.fold<double>(0, math.max);

          return DataRow(
            cells: [
              DataCell(Text(metric.label,
                  style: const TextStyle(color: _kMuted, fontSize: 11))),
              ...selected.map((service) {
                final value = rawValues[service]![i];
                final isBest = value == best && vals.where((v) => v == best).length < vals.length;
                return DataCell(
                  Text(
                    _formatValue(value),
                    style: TextStyle(
                      color: isBest ? _kGreen : _kSecondary,
                      fontSize: 11,
                      fontWeight:
                          isBest ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grouped bar comparison section
// ---------------------------------------------------------------------------

class _BarComparisonSection extends StatelessWidget {
  final List<String> selected;
  final Map<String, BenchmarkService> data;

  const _BarComparisonSection({required this.selected, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _radarMetrics.map((metric) {
            return _MetricBarGroup(
              metric: metric,
              selected: selected,
              data: data,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _MetricBarGroup extends StatelessWidget {
  final _MetricDef metric;
  final List<String> selected;
  final Map<String, BenchmarkService> data;

  const _MetricBarGroup({
    required this.metric,
    required this.selected,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final values = <String, double>{};
    for (final service in selected) {
      values[service] = data[service]?.summary[metric.summaryKey] ?? 0;
    }
    final maxVal = values.values.fold<double>(0, math.max);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                metric.label,
                style: const TextStyle(
                  color: _kSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (metric.inverted) ...[
                const SizedBox(width: 6),
                const Text(
                  '(lower is better)',
                  style: TextStyle(color: _kDim, fontSize: 10),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ...selected.map((service) {
            final value = values[service]!;
            final color = ServiceColors.getColor(service);
            final ratio = maxVal > 0 ? value / maxVal : 0.0;

            // Determine if this is the best value for the metric
            final isBest = metric.inverted
                ? value ==
                    values.values
                        .where((v) => v > 0)
                        .fold<double>(double.infinity, math.min)
                : value == values.values.fold<double>(0, math.max);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      BenchmarkProvider.frameworkName(service),
                      style: TextStyle(
                        color: isBest ? _kGreen : _kMuted,
                        fontSize: 11,
                        fontWeight:
                            isBest ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          children: [
                            Container(
                              height: 18,
                              decoration: BoxDecoration(
                                color: _kBorder.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOut,
                              height: 18,
                              width: constraints.maxWidth * ratio,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      _formatValue(value),
                      style: TextStyle(
                        color: isBest ? _kGreen : _kSecondary,
                        fontSize: 11,
                        fontWeight:
                            isBest ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Comparison table
// ---------------------------------------------------------------------------

class _ComparisonTable extends StatelessWidget {
  final List<String> selected;
  final Map<String, BenchmarkService> data;

  const _ComparisonTable({required this.selected, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            _kBorder.withValues(alpha: 0.3),
          ),
          dataRowColor: WidgetStateProperty.all(Colors.transparent),
          border: TableBorder(
            horizontalInside: BorderSide(color: _kBorder.withValues(alpha: 0.5)),
            verticalInside: BorderSide(color: _kBorder.withValues(alpha: 0.3)),
          ),
          columnSpacing: 24,
          columns: [
            const DataColumn(
              label: Text(
                'Metric',
                style: TextStyle(
                  color: _kText,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            ...selected.map((name) {
              final color = ServiceColors.getColor(name);
              return DataColumn(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      BenchmarkProvider.frameworkName(name),
                      style: const TextStyle(
                        color: _kText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          rows: _tableMetrics.map((metric) {
            // Gather values
            final values = <String, double>{};
            for (final service in selected) {
              values[service] =
                  data[service]?.summary[metric.summaryKey] ?? 0;
            }

            // Find best and worst
            final positiveValues =
                values.entries.where((e) => e.value > 0).toList();

            String? bestService;
            String? worstService;

            if (positiveValues.length >= 2) {
              if (metric.inverted) {
                bestService = positiveValues
                    .reduce((a, b) => a.value < b.value ? a : b)
                    .key;
                worstService = positiveValues
                    .reduce((a, b) => a.value > b.value ? a : b)
                    .key;
              } else {
                bestService = positiveValues
                    .reduce((a, b) => a.value > b.value ? a : b)
                    .key;
                worstService = positiveValues
                    .reduce((a, b) => a.value < b.value ? a : b)
                    .key;
              }
            }

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    metric.label,
                    style: const TextStyle(
                      color: _kSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ...selected.map((service) {
                  final value = values[service]!;
                  final isBest = service == bestService;
                  final isWorst = service == worstService;

                  Color textColor;
                  FontWeight weight;
                  if (isBest) {
                    textColor = _kGreen;
                    weight = FontWeight.w700;
                  } else if (isWorst) {
                    textColor = _kDim;
                    weight = FontWeight.w400;
                  } else {
                    textColor = _kSecondary;
                    weight = FontWeight.w400;
                  }

                  return DataCell(
                    Text(
                      _formatValue(value),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 12,
                        fontWeight: weight,
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatValue(double value) {
  if (value == 0) return '0';
  if (value >= 10000) return '${(value / 1000).toStringAsFixed(1)}K';
  if (value >= 100) return value.toStringAsFixed(1);
  if (value >= 10) return value.toStringAsFixed(2);
  return value.toStringAsFixed(2);
}
