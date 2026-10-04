import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/results.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';

const _axisStyle = TextStyle(color: kTextMuted, fontSize: 10.5);
const _sloMs = 100.0;

double _log2(double v) => math.log(v) / math.ln2;
double _log10(double v) => math.log(v) / math.ln10;

FlGridData _grid() => FlGridData(
  show: true,
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) =>
      const FlLine(color: kGridLine, strokeWidth: 1),
);

FlBorderData _border() => FlBorderData(
  show: true,
  border: const Border(
    bottom: BorderSide(color: kBorder),
    left: BorderSide(color: kBorder),
  ),
);

LineTouchData _touch(String Function(LineBarSpot s) label) => LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    getTooltipColor: (_) => kCardBgRaised.withValues(alpha: 0.96),
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipItems: (spots) => [
      for (final s in spots)
        LineTooltipItem(
          label(s),
          TextStyle(color: s.bar.color ?? kTextPrimary, fontSize: 11.5),
        ),
    ],
  ),
);

/// One backend's steps, for the step-load charts.
class StepSeries {
  final BackendResult backend;
  final List<LoadStep> steps;

  StepSeries(this.backend, this.steps)
    : assert(steps.every((s) => s.targetRps > 0));
}

enum StepChartMode { throughput, p99 }

/// Load-step curve. X: target rate on a log scale (each doubling equally
/// wide). Throughput mode: served vs requested, with the ideal diagonal.
/// p99 mode: p99 latency on a log scale with the 100 ms SLO line.
/// Hollow red dots are steps that missed the SLO.
class StepLoadChart extends StatelessWidget {
  final List<StepSeries> series;
  final StepChartMode mode;
  final double height;

  const StepLoadChart({
    super.key,
    required this.series,
    required this.mode,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    final all = [for (final s in series) ...s.steps];
    if (all.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No step data', style: TextStyle(color: kTextMuted)),
        ),
      );
    }
    final minX = _log2(all.map((s) => s.targetRps).reduce(math.min));
    final maxX = _log2(all.map((s) => s.targetRps).reduce(math.max));
    final throughput = mode == StepChartMode.throughput;

    double y(LoadStep s) => throughput
        ? _log2(math.max(s.achievedRps, 1))
        : _log10(math.max(s.p99, 0.1));

    final ys = all.map(y).toList();
    var minY = ys.reduce(math.min);
    var maxY = ys.reduce(math.max);
    if (throughput) {
      minY = math.min(minY, minX);
      maxY = math.max(maxY, maxX);
    } else {
      minY = math.min(minY, _log10(1));
      maxY = math.max(maxY, _log10(_sloMs * 2));
    }
    minY = minY.floorToDouble();
    maxY = maxY.ceilToDouble();

    String fmtY(double v) => throughput
        ? formatNumber(math.pow(2, v).toDouble())
        : formatMs(math.pow(10, v).toDouble());

    final bars = <LineChartBarData>[
      if (throughput)
        LineChartBarData(
          spots: [FlSpot(minX, minX), FlSpot(maxX, maxX)],
          color: kTextDim,
          barWidth: 1,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
        ),
      for (final s in series)
        LineChartBarData(
          spots: [for (final st in s.steps) FlSpot(_log2(st.targetRps), y(st))],
          color: BackendColors.of(s.backend.key),
          barWidth: 2,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, bar, index) {
              final step = s.steps[index];
              return FlDotCirclePainter(
                radius: step.pass ? 3 : 3.5,
                color: step.pass ? bar.color ?? kTextPrimary : kBackground,
                strokeColor: step.pass ? kBackground : kOrange,
                strokeWidth: step.pass ? 1 : 2,
              );
            },
          ),
        ),
    ];
    final offset = throughput ? 1 : 0;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: _grid(),
          borderData: _border(),
          lineBarsData: bars,
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (!throughput)
                HorizontalLine(
                  y: _log10(_sloMs),
                  color: kOrange.withValues(alpha: 0.7),
                  strokeWidth: 1,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(color: kOrange, fontSize: 10),
                    labelResolver: (_) => 'SLO 100 ms',
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              axisNameWidget: const Text('requested rps', style: _axisStyle),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 22,
                getTitlesWidget: (v, meta) => v != v.roundToDouble()
                    ? const SizedBox.shrink()
                    : Text(
                        formatNumber(math.pow(2, v).toDouble()),
                        style: _axisStyle,
                      ),
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: Text(
                throughput ? 'served rps' : 'p99 latency',
                style: _axisStyle,
              ),
              sideTitles: SideTitles(
                showTitles: true,
                interval: throughput ? 2 : 1,
                reservedSize: 46,
                getTitlesWidget: (v, meta) => v != v.roundToDouble()
                    ? const SizedBox.shrink()
                    : Text(fmtY(v), style: _axisStyle),
              ),
            ),
          ),
          lineTouchData: _touch((s) {
            if (s.barIndex - offset < 0) return '';
            final st = series[s.barIndex - offset].steps[s.spotIndex];
            final name = series[s.barIndex - offset].backend.name;
            return '$name @ ${formatNumber(st.targetRps)} rps\n'
                'served ${formatNumber(st.achievedRps)} · p99 ${formatMs(st.p99)}'
                '${st.errorRate > 0 ? ' · ${(st.errorRate * 100).toStringAsFixed(2)}% err' : ''}'
                '${st.pass ? '' : ' · missed SLO'}';
          }),
        ),
      ),
    );
  }
}

/// One line per backend over time for a time-series field (e.g. app_cpu).
class TimeSeriesChart extends StatelessWidget {
  final List<(BackendResult, TimeSeries)> series;
  final String field;

  /// Fixed formatter for axis labels and tooltips.
  final String Function(double)? format;

  /// Formatter chosen from the chart's maximum, so one unit serves the
  /// whole axis (memory: MB or GB, never both).
  final String Function(double) Function(double maxY)? formatFor;
  final double height;

  const TimeSeriesChart({
    super.key,
    required this.series,
    required this.field,
    this.format,
    this.formatFor,
    this.height = 220,
  }) : assert(format != null || formatFor != null);

  @override
  Widget build(BuildContext context) {
    final bars = <LineChartBarData>[];
    final names = <String>[];
    var maxT = 0.0;
    var maxY = 0.0;
    for (final (b, ts) in series) {
      final values = ts.series[field];
      if (values == null) continue;
      final spots = <FlSpot>[];
      for (var i = 0; i < ts.t.length && i < values.length; i++) {
        final v = values[i];
        if (v == null) continue;
        spots.add(FlSpot(ts.t[i], v));
        maxT = math.max(maxT, ts.t[i]);
        maxY = math.max(maxY, v);
      }
      if (spots.isEmpty) continue;
      names.add(b.name);
      bars.add(
        LineChartBarData(
          spots: spots,
          color: BackendColors.of(b.key),
          barWidth: 1.6,
          isCurved: false,
          dotData: const FlDotData(show: false),
        ),
      );
    }
    if (bars.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No data', style: TextStyle(color: kTextMuted)),
        ),
      );
    }
    final yInterval = _niceInterval(maxY);
    final format = formatFor?.call(maxY) ?? this.format!;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxT,
          minY: 0,
          maxY: (maxY / yInterval).ceil() * yInterval,
          gridData: _grid(),
          borderData: _border(),
          lineBarsData: bars,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: _niceInterval(maxT),
                getTitlesWidget: (v, meta) => v == meta.max
                    ? const SizedBox.shrink()
                    : Text('${v.toInt()}s', style: _axisStyle),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: yInterval,
                getTitlesWidget: (v, meta) => v == meta.max
                    ? const SizedBox.shrink()
                    : Text(format(v), style: _axisStyle),
              ),
            ),
          ),
          lineTouchData: _touch(
            (s) => '${names[s.barIndex]}: ${format(s.y)} @ ${s.x.toInt()}s',
          ),
        ),
      ),
    );
  }
}

double _niceInterval(double max) {
  if (max <= 0) return 1;
  final raw = max / 5;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  for (final m in [1, 2, 2.5, 5, 10]) {
    if (raw <= m * mag) return m * mag;
  }
  return 10 * mag;
}

/// Metric value per run date, one line per backend (History tab).
class HistoryChart extends StatelessWidget {
  final List<String> dates;
  final List<(String key, String name, List<double?> values)> lines;
  final String Function(double) format;

  const HistoryChart({
    super.key,
    required this.dates,
    required this.lines,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    var maxY = 0.0;
    final bars = <LineChartBarData>[];
    final names = <String>[];
    for (final (key, name, values) in lines) {
      final spots = <FlSpot>[
        for (var i = 0; i < values.length; i++)
          if (values[i] != null) FlSpot(i.toDouble(), values[i]!),
      ];
      if (spots.isEmpty) continue;
      for (final s in spots) {
        maxY = math.max(maxY, s.y);
      }
      names.add(name);
      bars.add(
        LineChartBarData(
          spots: spots,
          color: BackendColors.of(key),
          barWidth: 2,
          dotData: const FlDotData(show: true),
        ),
      );
    }
    if (bars.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text('No values', style: TextStyle(color: kTextMuted)),
        ),
      );
    }
    final interval = _niceInterval(maxY);
    final single = dates.length == 1;
    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          minX: single ? -0.5 : 0,
          maxX: single ? 0.5 : (dates.length - 1).toDouble(),
          minY: 0,
          maxY: (maxY / interval).ceil() * interval,
          gridData: _grid(),
          borderData: _border(),
          lineBarsData: bars,
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 24,
                getTitlesWidget: (v, meta) {
                  final i = v.round();
                  if (v != i || i < 0 || i >= dates.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(dates[i], style: _axisStyle);
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: interval,
                getTitlesWidget: (v, meta) => v == meta.max
                    ? const SizedBox.shrink()
                    : Text(format(v), style: _axisStyle),
              ),
            ),
          ),
          lineTouchData: _touch((s) => '${names[s.barIndex]}: ${format(s.y)}'),
        ),
      ),
    );
  }
}

/// Small legend row of colored names.
class ChartLegend extends StatelessWidget {
  final List<BackendResult> backends;

  const ChartLegend({super.key, required this.backends});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 14,
    runSpacing: 6,
    children: [
      for (final b in backends)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 3, color: BackendColors.of(b.key)),
            const SizedBox(width: 6),
            Text(
              b.name,
              style: const TextStyle(color: kTextSecondary, fontSize: 12),
            ),
          ],
        ),
    ],
  );
}
