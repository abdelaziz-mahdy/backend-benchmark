import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/benchmark_provider.dart';
import '../utils/colors.dart';

/// Formats a numeric value for display.
/// >= 1M -> "1.2M", >= 1K -> "1.2K", else 1 decimal place.
String _formatNumber(double value) {
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value.abs() >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  } else {
    return value.toStringAsFixed(1);
  }
}

/// Formats a percentage value with 1 decimal + "%".
String _formatPercent(double value) {
  return '${value.toStringAsFixed(1)}%';
}

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> {
  int _sortColumnIndex = 0;
  bool _sortAscending = false;

  // Theme colors
  static const _background = Color(0xFF0D1117);
  static const _cardBg = Color(0xFF161B22);
  static const _border = Color(0xFF30363D);
  static const _textPrimary = Color(0xFFE6EDF3);
  static const _textSecondary = Color(0xFFC9D1D9);
  static const _textMuted = Color(0xFF8B949E);
  static const _textDim = Color(0xFF484F58);
  static const _blue = Color(0xFF58A6FF);
  static const _green = Color(0xFF3FB950);
  static const _orange = Color(0xFFF78166);
  static const _teal = Color(0xFF00BFA5);

  @override
  Widget build(BuildContext context) {
    return Consumer<BenchmarkProvider>(
      builder: (context, provider, _) {
        if (provider.data == null) {
          return const Center(
            child: Text('No data', style: TextStyle(color: _textMuted)),
          );
        }

        return Container(
          color: _background,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Top Performers'),
                const SizedBox(height: 12),
                _buildWinnerCards(provider),
                const SizedBox(height: 32),
                _buildSectionTitle('Performance Comparison'),
                const SizedBox(height: 12),
                _buildBarChartSection(
                  provider,
                  title: 'Requests per Second',
                  metricKey: 'Average Requests/s',
                  ascending: false,
                  unit: 'req/s',
                ),
                const SizedBox(height: 24),
                _buildBarChartSection(
                  provider,
                  title: 'Average Response Time',
                  metricKey: 'Average Response Time (ms)',
                  ascending: true,
                  unit: 'ms',
                ),
                const SizedBox(height: 24),
                _buildBarChartSection(
                  provider,
                  title: 'P99 Response Time',
                  metricKey: 'Average Response Time 99% (ms)',
                  ascending: true,
                  unit: 'ms',
                ),
                const SizedBox(height: 32),
                _buildSectionTitle('Full Rankings'),
                const SizedBox(height: 12),
                _buildDataTable(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 1: Winner Cards
  // ---------------------------------------------------------------------------

  Widget _buildWinnerCards(BenchmarkProvider provider) {
    final winners = <_WinnerInfo>[
      _getWinner(
        provider,
        title: 'Fastest',
        metricKey: 'Average Requests/s',
        ascending: false,
        icon: Icons.bolt,
        color: _green,
        unit: 'req/s',
      ),
      _getWinner(
        provider,
        title: 'Lowest Latency',
        metricKey: 'Average Response Time (ms)',
        ascending: true,
        icon: Icons.timer,
        color: _blue,
        unit: 'ms',
      ),
      _getWinner(
        provider,
        title: 'CPU Efficient',
        metricKey: 'Average Server CPU Usage',
        ascending: true,
        icon: Icons.memory,
        color: _orange,
        isPercent: true,
      ),
      _getWinner(
        provider,
        title: 'Best P99 Latency',
        metricKey: 'Average Response Time 99% (ms)',
        ascending: true,
        icon: Icons.check_circle,
        color: _teal,
        unit: 'ms',
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: winners.map((w) => _buildWinnerCard(w, provider)).toList(),
    );
  }

  _WinnerInfo _getWinner(
    BenchmarkProvider provider, {
    required String title,
    required String metricKey,
    required bool ascending,
    required IconData icon,
    required Color color,
    String unit = '',
    bool isPercent = false,
  }) {
    final ranked = provider.getRankedServices(metricKey, ascending: ascending);
    if (ranked.isEmpty) {
      return _WinnerInfo(
        title: title,
        icon: icon,
        color: color,
        value: '--',
        frameworkName: 'N/A',
        serviceName: '',
      );
    }
    final winner = ranked.first;
    final formatted = isPercent
        ? _formatPercent(winner.value)
        : '${_formatNumber(winner.value)} $unit'.trim();
    return _WinnerInfo(
      title: title,
      icon: icon,
      color: color,
      value: formatted,
      frameworkName: BenchmarkProvider.frameworkName(winner.key),
      serviceName: winner.key,
    );
  }

  Widget _buildWinnerCard(_WinnerInfo info, BenchmarkProvider provider) {
    return SizedBox(
      width: 220,
      child: Card(
        color: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: _border),
        ),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: info.serviceName.isNotEmpty
              ? () => provider.selectDetailService(info.serviceName)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(info.icon, color: info.color, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      info.title,
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  info.value,
                  style: TextStyle(
                    color: info.color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.frameworkName,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 2: Horizontal Bar Charts (custom widget-based)
  // ---------------------------------------------------------------------------

  Widget _buildBarChartSection(
    BenchmarkProvider provider, {
    required String title,
    required String metricKey,
    required bool ascending,
    required String unit,
  }) {
    final ranked = provider.getRankedServices(metricKey, ascending: ascending);
    if (ranked.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxValue = ranked
        .map((e) => e.value)
        .reduce((a, b) => a > b ? a : b);

    return Card(
      color: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _border),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  ascending ? '(lower is better)' : '(higher is better)',
                  style: const TextStyle(color: _textMuted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...ranked.map((entry) => _buildBarRow(
                  provider,
                  serviceName: entry.key,
                  value: entry.value,
                  maxValue: maxValue,
                  unit: unit,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildBarRow(
    BenchmarkProvider provider, {
    required String serviceName,
    required double value,
    required double maxValue,
    required String unit,
  }) {
    final color = ServiceColors.getColor(serviceName);
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    final name = BenchmarkProvider.frameworkName(serviceName);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => provider.selectDetailService(serviceName),
                child: Text(
                  name,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: _border.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 22,
                      width: constraints.maxWidth * fraction,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              '${_formatNumber(value)} $unit',
              style: const TextStyle(
                color: _textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section 3: Sortable Data Table
  // ---------------------------------------------------------------------------

  // Column definitions: (label, metricKey, isPercent, ascending-is-better)
  static const _columns = <_ColumnDef>[
    _ColumnDef('Framework', '', false, false),
    _ColumnDef('Req/s', 'Average Requests/s', false, false),
    _ColumnDef('Avg (ms)', 'Average Response Time (ms)', false, true),
    _ColumnDef('P50', 'Average Response Time 50% (ms)', false, true),
    _ColumnDef('P99', 'Average Response Time 99% (ms)', false, true),
    _ColumnDef('Failures/s', 'Average Failures/s', false, true),
    _ColumnDef('CPU%', 'Average Server CPU Usage', true, true),
    _ColumnDef('DB CPU%', 'Average Database CPU Usage', true, true),
  ];

  Widget _buildDataTable(BenchmarkProvider provider) {
    // Build row data from filtered services
    final services = provider.testTypeFilter == TestTypeFilter.all
        ? provider.data!.keys.toList()
        : provider.testTypeFilter == TestTypeFilter.db
            ? provider.dbServices
            : provider.noDbServices;

    if (services.isEmpty) {
      return const Text('No services available',
          style: TextStyle(color: _textMuted));
    }

    // Build rows with all metric values
    final rows = <_RowData>[];
    for (final svc in services) {
      final summary = provider.data![svc]?.summary;
      if (summary == null) continue;
      final values = <double>[];
      for (int i = 1; i < _columns.length; i++) {
        values.add(summary[_columns[i].metricKey] ?? 0);
      }
      rows.add(_RowData(serviceName: svc, values: values));
    }

    // Sort rows
    if (_sortColumnIndex == 0) {
      // Sort by framework name
      rows.sort((a, b) {
        final nameA = BenchmarkProvider.frameworkName(a.serviceName);
        final nameB = BenchmarkProvider.frameworkName(b.serviceName);
        return _sortAscending
            ? nameA.compareTo(nameB)
            : nameB.compareTo(nameA);
      });
    } else {
      final idx = _sortColumnIndex - 1;
      rows.sort((a, b) {
        return _sortAscending
            ? a.values[idx].compareTo(b.values[idx])
            : b.values[idx].compareTo(a.values[idx]);
      });
    }

    // Compute best/worst per column (for highlighting)
    final bestIndices = <int, int>{};
    final worstIndices = <int, int>{};
    for (int col = 0; col < _columns.length - 1; col++) {
      if (rows.isEmpty) continue;
      final colDef = _columns[col + 1];
      double bestVal = rows.first.values[col];
      double worstVal = rows.first.values[col];
      int bestIdx = 0;
      int worstIdx = 0;
      for (int r = 1; r < rows.length; r++) {
        final v = rows[r].values[col];
        if (colDef.ascendingIsBetter) {
          // Lower is better
          if (v < bestVal) {
            bestVal = v;
            bestIdx = r;
          }
          if (v > worstVal) {
            worstVal = v;
            worstIdx = r;
          }
        } else {
          // Higher is better
          if (v > bestVal) {
            bestVal = v;
            bestIdx = r;
          }
          if (v < worstVal || (v > 0 && worstVal == 0)) {
            worstVal = v;
            worstIdx = r;
          }
        }
      }
      bestIndices[col] = bestIdx;
      worstIndices[col] = worstIdx;
    }

    return Card(
      color: _cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: _border),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          headingRowColor: WidgetStateProperty.all(_cardBg),
          dataRowColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.hovered)) {
              return _border.withValues(alpha: 0.3);
            }
            return _cardBg;
          }),
          headingTextStyle: const TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          dividerThickness: 1,
          horizontalMargin: 16,
          columnSpacing: 24,
          columns: List.generate(_columns.length, (i) {
            return DataColumn(
              label: Text(_columns[i].label),
              numeric: i > 0,
              onSort: (colIndex, ascending) {
                setState(() {
                  _sortColumnIndex = colIndex;
                  _sortAscending = ascending;
                });
              },
            );
          }),
          rows: List.generate(rows.length, (rowIdx) {
            final row = rows[rowIdx];
            final name = BenchmarkProvider.frameworkName(row.serviceName);
            return DataRow(
              cells: [
                DataCell(
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () =>
                          provider.selectDetailService(row.serviceName),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                ...List.generate(_columns.length - 1, (colIdx) {
                  final value = row.values[colIdx];
                  final colDef = _columns[colIdx + 1];
                  final isBest = bestIndices[colIdx] == rowIdx;
                  final isWorst = worstIndices[colIdx] == rowIdx;

                  Color textColor = _textSecondary;
                  if (isBest) textColor = _green;
                  if (isWorst) textColor = _textDim;

                  final formatted = colDef.isPercent
                      ? _formatPercent(value)
                      : _formatNumber(value);

                  return DataCell(
                    Text(
                      formatted,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: isBest ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper data classes
// ---------------------------------------------------------------------------

class _WinnerInfo {
  final String title;
  final IconData icon;
  final Color color;
  final String value;
  final String frameworkName;
  final String serviceName;

  const _WinnerInfo({
    required this.title,
    required this.icon,
    required this.color,
    required this.value,
    required this.frameworkName,
    required this.serviceName,
  });
}

class _ColumnDef {
  final String label;
  final String metricKey;
  final bool isPercent;
  final bool ascendingIsBetter; // true if lower values are better

  const _ColumnDef(
      this.label, this.metricKey, this.isPercent, this.ascendingIsBetter);
}

class _RowData {
  final String serviceName;
  final List<double> values;

  const _RowData({required this.serviceName, required this.values});
}
