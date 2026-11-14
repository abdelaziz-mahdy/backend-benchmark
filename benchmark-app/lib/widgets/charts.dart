import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../models/results.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';

// Instrument-trace styling shared by every chart: no frame, faint
// horizontal rules, monospaced tick labels.
final _axisStyle = mono(10.5, color: kTextDim, weight: FontWeight.w400);
final _axisNameStyle = body(11, color: kTextMuted);
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
  border: const Border(bottom: BorderSide(color: kBorder)),
);

LineTouchData _touch(String Function(LineBarSpot s) label) => LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    getTooltipColor: (_) => kCardBgRaised.withValues(alpha: 0.97),
    tooltipBorder: const BorderSide(color: kBorderStrong),
    fitInsideHorizontally: true,
    fitInsideVertically: true,
    getTooltipItems: (spots) => [
      for (final s in spots)
        s.bar.color == null || label(s).isEmpty
            ? null
            : LineTooltipItem(
                label(s),
                mono(11.5, color: s.bar.color ?? kTextPrimary),
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

/// Load-step curve on log axes. X: requested rate, ticks at the real step
/// rates (each step doubles, so they are evenly spaced). Throughput mode:
/// served vs requested with the "served everything" diagonal. p99 mode:
/// p99 with the 100 ms SLO and the red zone above it. Hollow red points
/// are steps that failed a limit. With one series and [sustainable], a
/// lime pin marks the sustainable load.
class StepLoadChart extends StatelessWidget {
  final List<StepSeries> series;
  final StepChartMode mode;
  final double height;
  final double? sustainable;

  const StepLoadChart({
    super.key,
    required this.series,
    required this.mode,
    this.height = 270,
    this.sustainable,
  });

  @override
  Widget build(BuildContext context) {
    final all = [for (final s in series) ...s.steps];
    if (all.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No step data', style: body(13, color: kTextMuted)),
        ),
      );
    }
    // Steps are base × 2^k, so x = log2(rate / base) puts every step on a
    // whole number and the tick labels are the real rates.
    final base = all.map((s) => s.targetRps).reduce(math.min);
    double lx(double rps) => _log2(math.max(rps, 1) / base);
    final maxX = lx(all.map((s) => s.targetRps).reduce(math.max));
    final throughput = mode == StepChartMode.throughput;

    double y(LoadStep s) =>
        throughput ? lx(s.achievedRps) : _log10(math.max(s.p99, 0.1));

    final ys = all.map(y).toList();
    var minY = ys.reduce(math.min);
    var maxY = ys.reduce(math.max);
    if (throughput) {
      minY = math.min(minY, 0);
      maxY = math.max(maxY, maxX);
    } else {
      minY = math.min(minY, _log10(1));
      maxY = math.max(maxY, _log10(_sloMs * 3));
    }
    minY = minY.floorToDouble();
    maxY = maxY.ceilToDouble();

    String fmtX(double v) => compactRps(base * math.pow(2, v));
    String fmtY(double v) {
      if (throughput) return compactRps(base * math.pow(2, v));
      final ms = math.pow(10, v).toDouble();
      if (ms >= 1000) return '${(ms / 1000).round()} s';
      return ms >= 1 ? '${ms.round()} ms' : '${ms.toStringAsFixed(1)} ms';
    }

    final single = series.length == 1;
    final bars = <LineChartBarData>[
      if (throughput)
        LineChartBarData(
          spots: [const FlSpot(0, 0), FlSpot(maxX, maxX)],
          color: kTextDim,
          barWidth: 1,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
        ),
      for (final s in series)
        LineChartBarData(
          spots: [for (final st in s.steps) FlSpot(lx(st.targetRps), y(st))],
          color: BackendColors.of(s.backend.key),
          barWidth: 2.2,
          belowBarData: single
              ? BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      BackendColors.of(s.backend.key).withValues(alpha: 0.28),
                      BackendColors.of(s.backend.key).withValues(alpha: 0),
                    ],
                  ),
                )
              : null,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, bar, index) {
              final step = s.steps[index];
              return FlDotCirclePainter(
                radius: step.pass ? 2.8 : 4,
                color: step.pass ? bar.color ?? kTextPrimary : kCardBg,
                // Amber: the load generator, not the app, was the limit.
                strokeColor: step.pass
                    ? kCardBg
                    : (step.k6Bound ? kAmber : kRedline),
                strokeWidth: step.pass ? 1 : 2,
              );
            },
          ),
        ),
    ];
    final offset = throughput ? 1 : 0;
    final pin = single && sustainable != null && sustainable! > 0
        ? lx(sustainable!)
        : null;

    return SizedBox(
      height: height,
      child: LineChart(
        duration: motion(context, 500),
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          gridData: _grid(),
          borderData: _border(),
          lineBarsData: bars,
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              if (!throughput)
                HorizontalRangeAnnotation(
                  y1: _log10(_sloMs),
                  y2: maxY,
                  color: kRedline.withValues(alpha: 0.08),
                ),
            ],
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (!throughput)
                HorizontalLine(
                  y: _log10(_sloMs),
                  color: kRedline.withValues(alpha: 0.8),
                  strokeWidth: 1,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    style: mono(10.5, color: kRedline, weight: FontWeight.w700),
                    labelResolver: (_) => 'SLO 100 ms',
                  ),
                ),
            ],
            verticalLines: [
              if (pin != null)
                VerticalLine(
                  x: pin,
                  color: kSignal.withValues(alpha: 0.85),
                  strokeWidth: 1.5,
                  dashArray: [3, 3],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: throughput
                        ? Alignment.topLeft
                        : Alignment.bottomLeft,
                    padding: const EdgeInsets.only(right: 4, top: 2),
                    style: mono(10.5, color: kSignal, weight: FontWeight.w700),
                    labelResolver: (_) =>
                        'sustainable ${formatNumber(sustainable!)}',
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              axisNameSize: 18,
              axisNameWidget: Text(
                'requested req/s (log scale)',
                style: _axisNameStyle,
              ),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 22,
                getTitlesWidget: (v, meta) => v != v.roundToDouble()
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(fmtX(v), style: _axisStyle),
                      ),
              ),
            ),
            leftTitles: AxisTitles(
              axisNameSize: 18,
              axisNameWidget: Text(
                throughput ? 'served req/s (log)' : 'p99 (log)',
                style: _axisNameStyle,
              ),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 48,
                getTitlesWidget: (v, meta) =>
                    v != v.roundToDouble() || v == meta.min
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(fmtY(v), style: _axisStyle),
                      ),
              ),
            ),
          ),
          lineTouchData: _touch((s) {
            if (s.barIndex - offset < 0) return '';
            final st = series[s.barIndex - offset].steps[s.spotIndex];
            final name = series[s.barIndex - offset].backend.name;
            return '$name @ ${formatNumber(st.targetRps)} req/s\n'
                'served ${formatNumber(st.achievedRps)} · p99 ${formatMs(st.p99)}'
                '${st.errorRate > 0 ? ' · ${(st.errorRate * 100).toStringAsFixed(2)}% err' : ''}'
                '${st.pass
                    ? ''
                    : st.k6Bound
                    ? ' · failed at the load generator\'s limit'
                    : ' · failed'}';
          }),
        ),
      ),
    );
  }
}

/// One line per backend over time for a time-series field (e.g. app_cpu).
/// A single series gets a gradient fill; [ceiling] draws a dashed limit
/// (e.g. the cores the app was given).
class TimeSeriesChart extends StatelessWidget {
  final List<(BackendResult, TimeSeries)> series;
  final String field;

  /// Fixed formatter for axis labels and tooltips.
  final String Function(double)? format;

  /// Formatter chosen from the chart's maximum, so one unit serves the
  /// whole axis (memory: MB or GB, never both).
  final String Function(double) Function(double maxY)? formatFor;
  final double height;
  final double? ceiling;
  final String? ceilingLabel;

  const TimeSeriesChart({
    super.key,
    required this.series,
    required this.field,
    this.format,
    this.formatFor,
    this.height = 230,
    this.ceiling,
    this.ceilingLabel,
  }) : assert(format != null || formatFor != null);

  @override
  Widget build(BuildContext context) {
    final bars = <LineChartBarData>[];
    final names = <String>[];
    var maxT = 0.0;
    var maxY = 0.0;
    final single = series.length == 1;
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
      final color = BackendColors.of(b.key);
      bars.add(
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 1.6,
          isCurved: false,
          dotData: const FlDotData(show: false),
          belowBarData: single
              ? BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.32),
                      color.withValues(alpha: 0),
                    ],
                  ),
                )
              : null,
        ),
      );
    }
    if (bars.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No data', style: body(13, color: kTextMuted)),
        ),
      );
    }
    final top = ceiling == null ? maxY : math.max(maxY, ceiling! * 1.05);
    final yInterval = _niceInterval(top);
    final format = formatFor?.call(top) ?? this.format!;
    return SizedBox(
      height: height,
      child: LineChart(
        duration: motion(context, 500),
        LineChartData(
          minX: 0,
          maxX: maxT,
          minY: 0,
          maxY: (top / yInterval).ceil() * yInterval,
          gridData: _grid(),
          borderData: _border(),
          lineBarsData: bars,
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (ceiling != null)
                HorizontalLine(
                  y: ceiling!,
                  color: kTextMuted.withValues(alpha: 0.7),
                  strokeWidth: 1,
                  dashArray: [5, 4],
                  label: HorizontalLineLabel(
                    show: ceilingLabel != null,
                    alignment: Alignment.topRight,
                    style: mono(10.5, color: kTextMuted),
                    labelResolver: (_) => ceilingLabel ?? '',
                  ),
                ),
            ],
          ),
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
                    : SideTitleWidget(
                        meta: meta,
                        child: Text('${v.toInt()}s', style: _axisStyle),
                      ),
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                interval: yInterval,
                getTitlesWidget: (v, meta) => v == meta.max
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        child: Text(format(v), style: _axisStyle),
                      ),
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

/// X-axis labels for a list of runs: the date, plus the commit when two
/// runs share a date ("2026-10-04 · 3ae75a8").
List<String> runAxisLabels(List<RunIndexEntry> runs) {
  final dates = [for (final r in runs) r.date ?? '?'];
  return [
    for (var i = 0; i < runs.length; i++)
      dates.where((d) => d == dates[i]).length > 1
          ? '${dates[i]} · ${_shortRun(runs[i].id)}'
          : dates[i],
  ];
}

/// "2026-10-04_m2pro-10c-32g_3ae75a8_cea6" → "3ae75a8".
String _shortRun(String id) {
  final parts = id.split('_');
  return parts.length >= 3 ? parts[2] : id;
}

/// Metric value per run, one line per backend (History). Frameworks with a
/// single run are dots; [highlight] dims every other line.
class HistoryChart extends StatelessWidget {
  final List<String> labels;
  final List<(String key, String name, List<double?> values)> lines;
  final String Function(double) format;
  final String? highlight;

  const HistoryChart({
    super.key,
    required this.labels,
    required this.lines,
    required this.format,
    this.highlight,
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
      final dim = highlight != null && highlight != key;
      final color = BackendColors.of(key).withValues(alpha: dim ? 0.18 : 1);
      bars.add(
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: highlight == key ? 3 : 2,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, bar, _) => FlDotCirclePainter(
              radius: highlight == key ? 5 : 4,
              color: color,
              strokeColor: kCardBg,
              strokeWidth: 1.5,
            ),
          ),
        ),
      );
    }
    if (bars.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text('No values', style: body(13, color: kTextMuted)),
        ),
      );
    }
    // Headroom above the highest point, so it sits under a labelled line.
    final interval = _niceInterval(maxY * 1.1);
    final top = ((maxY * 1.1) / interval).ceil() * interval;
    final single = labels.length == 1;
    return SizedBox(
      height: 260,
      child: LineChart(
        duration: motion(context, 400),
        LineChartData(
          minX: single ? -0.5 : -0.15,
          maxX: single ? 0.5 : labels.length - 1 + 0.15,
          minY: 0,
          maxY: top,
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
                  if ((v - i).abs() > 0.001 || i < 0 || i >= labels.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                    child: Text(labels[i], style: _axisStyle),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 52,
                interval: interval,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(format(v), style: _axisStyle),
                ),
              ),
            ),
          ),
          lineTouchData: _touch((s) => '${names[s.barIndex]}: ${format(s.y)}'),
        ),
      ),
    );
  }
}

/// Legend row: identity swatch and name per framework.
class ChartLegend extends StatelessWidget {
  final List<BackendResult> backends;

  const ChartLegend({super.key, required this.backends});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 6,
    children: [
      for (final b in backends)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: BackendColors.of(b.key),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(b.name, style: body(12, color: kTextSecondary)),
          ],
        ),
    ],
  );
}
