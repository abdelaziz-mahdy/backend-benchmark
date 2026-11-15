import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../models/plain.dart';
import '../models/results.dart';
import '../utils/colors.dart';
import '../utils/theme_constants.dart';

// Styling shared by every chart: no frame, faint horizontal rules, quiet
// tick labels in the page colours.
TextStyle _axisStyle(Palette p) =>
    mono(11, color: p.muted, weight: FontWeight.w400);
TextStyle _axisNameStyle(Palette p) => body(12, color: p.muted);
const _sloMs = 100.0;

double _log2(double v) => math.log(v) / math.ln2;
double _log10(double v) => math.log(v) / math.ln10;

FlGridData _grid(Palette p) => FlGridData(
  show: true,
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) =>
      FlLine(color: p.line.withValues(alpha: 0.6), strokeWidth: 1),
);

FlBorderData _border(Palette p) => FlBorderData(
  show: true,
  border: Border(bottom: BorderSide(color: p.line)),
);

LineTouchData _touch(Palette p, String Function(LineBarSpot s) label) =>
    LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => p.surface.withValues(alpha: 0.97),
        tooltipBorder: BorderSide(color: p.line),
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: (spots) => [
          for (final s in spots)
            s.bar.color == null || label(s).isEmpty
                ? null
                : LineTooltipItem(label(s), mono(12, color: p.text)),
        ],
      ),
    );

/// One backend's steps, for the step-load charts.
class StepSeries {
  final BackendResult backend;
  final List<LoadStep> steps;

  /// Its result hit our testing tool's limit: a step that only fell short
  /// of answering enough (fast replies, few errors) is the tool's limit too.
  final bool capped;

  StepSeries(this.backend, this.steps, {this.capped = false})
    : assert(steps.every((s) => s.targetRps > 0));

  /// The testing tool, not the app, was the limit at [step]: flagged so, or
  /// it only fell short of answering enough (fast replies, few errors)
  /// while the result hit the tool's limit. One rule for colour and words.
  bool toolLimited(LoadStep step) =>
      step.k6Bound ||
      (capped && !step.pass && step.p99 < _sloMs && step.errorRate < 0.01);

  /// Any of its steps stopped at the testing tool's limit.
  bool get anyToolLimited => steps.any(toolLimited);
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

  /// The result hit our testing tool's limit: its pin reads "40,000+".
  final bool capped;

  const StepLoadChart({
    super.key,
    required this.series,
    required this.mode,
    this.height = 270,
    this.sustainable,
    this.capped = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final all = [for (final s in series) ...s.steps];
    if (all.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text('No step data', style: body(13, color: p.muted)),
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

    // Full numbers ("4,000") as everywhere else on the site.
    String fmtX(double v) => whole(base * math.pow(2, v));
    String fmtY(double v) {
      if (throughput) return whole(base * math.pow(2, v));
      final ms = math.pow(10, v).toDouble();
      if (ms >= 1000) return '${(ms / 1000).round()} s';
      return ms >= 1 ? '${ms.round()} ms' : '${ms.toStringAsFixed(1)} ms';
    }

    final single = series.length == 1;
    final bars = <LineChartBarData>[
      if (throughput)
        LineChartBarData(
          spots: [const FlSpot(0, 0), FlSpot(maxX, maxX)],
          color: p.muted,
          barWidth: 1,
          dashArray: [4, 4],
          dotData: const FlDotData(show: false),
        ),
      for (final s in series)
        LineChartBarData(
          spots: [for (final st in s.steps) FlSpot(lx(st.targetRps), y(st))],
          color: identityColor(p, s.backend.key),
          barWidth: 2.2,
          belowBarData: single
              ? BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      identityColor(p, s.backend.key).withValues(alpha: 0.28),
                      identityColor(p, s.backend.key).withValues(alpha: 0),
                    ],
                  ),
                )
              : null,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, bar, index) {
              final step = s.steps[index];
              // A hollow amber square: the load generator, not the app, was
              // the limit. The shape tells it apart from a line coloured
              // near amber.
              if (!step.pass && s.toolLimited(step)) {
                return FlDotSquarePainter(
                  size: 7,
                  color: p.surface,
                  strokeColor: p.warn,
                  strokeWidth: 2,
                );
              }
              return FlDotCirclePainter(
                radius: step.pass ? 2.8 : 4,
                color: step.pass ? bar.color ?? p.text : p.surface,
                strokeColor: step.pass ? p.surface : p.danger,
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
          gridData: _grid(p),
          borderData: _border(p),
          lineBarsData: bars,
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              if (!throughput)
                HorizontalRangeAnnotation(
                  y1: _log10(_sloMs),
                  y2: maxY,
                  color: p.danger.withValues(alpha: 0.08),
                ),
            ],
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (!throughput)
                HorizontalLine(
                  y: _log10(_sloMs),
                  color: p.danger.withValues(alpha: 0.8),
                  strokeWidth: 1,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topLeft,
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    style: mono(10.5, color: p.danger, weight: FontWeight.w700),
                    labelResolver: (_) => 'limit 100 ms',
                  ),
                ),
            ],
            verticalLines: [
              if (pin != null)
                VerticalLine(
                  x: pin,
                  color: p.accent.withValues(alpha: 0.85),
                  strokeWidth: 1.5,
                  dashArray: [3, 3],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: throughput
                        ? Alignment.topLeft
                        : Alignment.bottomLeft,
                    padding: const EdgeInsets.only(right: 4, top: 2),
                    style: mono(10.5, color: p.accent, weight: FontWeight.w700),
                    labelResolver: (_) =>
                        'result ${whole(sustainable!)}${capped ? '+' : ''}',
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
                'requests a second asked for',
                style: _axisNameStyle(p),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 22,
                // A phone labels every other doubling, counted back from the
                // last, so labels never run together and the last one shows.
                getTitlesWidget: (v, meta) =>
                    v != v.roundToDouble() ||
                        (MediaQuery.sizeOf(context).width < 480 &&
                            (maxX.round() - v.round()).isOdd)
                    ? const SizedBox.shrink()
                    : SideTitleWidget(
                        meta: meta,
                        // The last label stays inside the chart.
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(fmtX(v), style: _axisStyle(p)),
                      ),
              ),
            ),
            leftTitles: AxisTitles(
              axisNameSize: 18,
              axisNameWidget: Text(
                throughput ? 'handled a second' : '99 in 100 within',
                style: _axisNameStyle(p),
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
                        child: Text(fmtY(v), style: _axisStyle(p)),
                      ),
              ),
            ),
          ),
          lineTouchData: _touch(p, (s) {
            if (s.barIndex - offset < 0) return '';
            final st = series[s.barIndex - offset].steps[s.spotIndex];
            final name = series[s.barIndex - offset].backend.name;
            return '$name, asked for ${whole(st.targetRps)} a second\n'
                'handled ${whole(st.achievedRps)} · 99 in 100 within '
                '${msText(st.p99)}'
                '${st.errorRate > 0 ? ' · ${(st.errorRate * 100).toStringAsFixed(2)}% failed' : ''}'
                '${st.pass
                    ? ''
                    : series[s.barIndex - offset].toolLimited(st)
                    ? " · stopped at our testing tool's limit"
                    : ' · missed the limits'}';
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

  /// Divides every value: the app processor is recorded per core (100% is
  /// one core) and shown as a share of the app's cores.
  final double divideBy;

  /// Caps every value: a share of cores never reads above 100%, as in the
  /// tables (short readings can poke a little past the limit).
  final double? maxValue;

  const TimeSeriesChart({
    super.key,
    required this.series,
    required this.field,
    this.format,
    this.formatFor,
    this.height = 230,
    this.ceiling,
    this.ceilingLabel,
    this.divideBy = 1,
    this.maxValue,
  }) : assert(format != null || formatFor != null);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
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
        final raw = values[i];
        if (raw == null) continue;
        final v = maxValue == null
            ? raw / divideBy
            : math.min(maxValue!, raw / divideBy);
        spots.add(FlSpot(ts.t[i], v));
        maxT = math.max(maxT, ts.t[i]);
        maxY = math.max(maxY, v);
      }
      if (spots.isEmpty) continue;
      names.add(b.name);
      final color = identityColor(p, b.key);
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
          child: Text('No data', style: body(13, color: p.muted)),
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
          gridData: _grid(p),
          borderData: _border(p),
          lineBarsData: bars,
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (ceiling != null)
                HorizontalLine(
                  y: ceiling!,
                  color: p.muted.withValues(alpha: 0.7),
                  strokeWidth: 1,
                  dashArray: [5, 4],
                  label: HorizontalLineLabel(
                    show: ceilingLabel != null,
                    alignment: Alignment.topRight,
                    style: mono(10.5, color: p.muted),
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
                        child: Text('${v.toInt()}s', style: _axisStyle(p)),
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
                        child: Text(format(v), style: _axisStyle(p)),
                      ),
              ),
            ),
          ),
          lineTouchData: _touch(
            p,
            (s) =>
                '${names[s.barIndex]}: ${format(s.y)} at ${s.x.toInt()} '
                'seconds',
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
    this.top,
    this.capped = const {},
  });

  /// A fixed top for the value axis (100 for a share of cores).
  final double? top;

  /// Frameworks whose newest point hit our testing tool's limit: that
  /// point's tooltip reads "40,000+".
  final Set<String> capped;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    var maxY = 0.0;
    final bars = <LineChartBarData>[];
    final names = <String>[];
    final keys = <String>[];
    final lastSpot = <int>[];
    // Frameworks with equal numbers at one run would hide each other's
    // dots: nudge them apart sideways, in a fixed order.
    final shared = <(int, double), List<String>>{};
    for (final (key, _, values) in lines) {
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        if (v != null) (shared[(i, v)] ??= []).add(key);
      }
    }
    double nudge(String key, int i, double v) {
      final same = shared[(i, v)]!;
      if (same.length < 2) return 0;
      return (same.indexOf(key) - (same.length - 1) / 2) * 0.07;
    }

    // The highlighted line is drawn last, on top of the faded ones.
    final ordered = [
      for (final l in lines)
        if (l.$1 != highlight) l,
      for (final l in lines)
        if (l.$1 == highlight) l,
    ];
    for (final (key, name, values) in ordered) {
      final spots = <FlSpot>[
        for (var i = 0; i < values.length; i++)
          if (values[i] != null)
            FlSpot(i + nudge(key, i, values[i]!), values[i]!),
      ];
      if (spots.isEmpty) continue;
      for (final s in spots) {
        maxY = math.max(maxY, s.y);
      }
      names.add(name);
      keys.add(key);
      lastSpot.add(spots.length - 1);
      final dim = highlight != null && highlight != key;
      final color = identityColor(p, key).withValues(alpha: dim ? 0.18 : 1);
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
              strokeColor: p.surface,
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
          child: Text('No values', style: body(13, color: p.muted)),
        ),
      );
    }
    // Headroom above the highest point, so it sits under a labelled line.
    final interval = this.top != null
        ? this.top! / 4
        : _niceInterval(maxY * 1.1);
    final top = this.top ?? ((maxY * 1.1) / interval).ceil() * interval;
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
          gridData: _grid(p),
          borderData: _border(p),
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
                    child: Text(labels[i], style: _axisStyle(p)),
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
                  child: Text(format(v), style: _axisStyle(p)),
                ),
              ),
            ),
          ),
          lineTouchData: _touch(
            p,
            (s) =>
                '${names[s.barIndex]}: ${format(s.y)}'
                '${capped.contains(keys[s.barIndex]) && s.spotIndex == lastSpot[s.barIndex] ? '+' : ''}',
          ),
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
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
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
                  color: identityColor(p, b.key),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(b.name, style: body(13, color: p.text)),
            ],
          ),
      ],
    );
  }
}
