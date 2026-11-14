import '../models/metrics.dart';

/// Formats a numeric value for display.
/// >= 1M -> "1.2M", >= 1K -> "1.2K", whole numbers show as int, else 1-2 decimals.
String formatNumber(double value) {
  if (value.abs() >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M';
  } else if (value.abs() >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  } else if (value == value.roundToDouble()) {
    return value.toInt().toString();
  } else if (value.abs() >= 100) {
    return value.toStringAsFixed(1);
  } else {
    return value.toStringAsFixed(2);
  }
}

/// Formats a percentage value with 1 decimal + "%".
String formatPercent(double value) {
  return '${value.toStringAsFixed(1)}%';
}

/// Value with the metric's unit; "—" when missing.
String formatMetric(Metric metric, double? value) {
  if (value == null) return '—';
  return switch (metric.unit) {
    Unit.rps => '${formatRps(value)} req/s',
    Unit.ms => formatMs(value),
    Unit.percent => _percentShare(value),
    Unit.cpu => '${value.toStringAsFixed(0)}%',
    Unit.mb => formatMb(value),
    Unit.ratio => formatRps(value),
  };
}

/// Request rates: whole requests below 1000 ("258", not "258.0"), then
/// "1.5K" / "1.2M". A fraction of a request per second is false precision.
String formatRps(double value) =>
    value.abs() >= 1000 ? formatNumber(value) : '${value.round()}';

/// Value without unit, for dense table cells.
String formatMetricShort(Metric metric, double? value) {
  if (value == null) return '—';
  return switch (metric.unit) {
    Unit.ms => formatMs(value),
    Unit.percent => _percentShare(value),
    Unit.cpu => '${value.toStringAsFixed(0)}%',
    Unit.mb => formatMb(value),
    _ => formatRps(value),
  };
}

String formatMs(double ms) {
  if (ms >= 1000) return '${(ms / 1000).toStringAsFixed(1)} s';
  if (ms >= 100) return '${ms.toStringAsFixed(0)} ms';
  if (ms >= 10) return '${ms.toStringAsFixed(1)} ms';
  return '${ms.toStringAsFixed(2)} ms';
}

/// Error rates are stored as a 0..1 share.
String _percentShare(double share) {
  final p = share * 100;
  if (p == 0) return '0%';
  if (p < 0.01) return '<0.01%';
  return '${p.toStringAsFixed(p < 1 ? 2 : 1)}%';
}

/// Megabytes, switching to GB from 1000 MB ("1.9 GB" not "1.9K MB").
String formatMb(double mb) => mb >= 1000
    ? '${(mb / 1024).toStringAsFixed(1)} GB'
    : '${formatNumber(mb)} MB';

/// Axis/tooltip formatter for a memory chart whose largest value is [maxMb]:
/// one unit for the whole chart ("0.5 GB / 1.0 GB" or "50 MB / 100 MB"),
/// never a mix such as "2.0K MB".
String Function(double) memoryAxisFormatter(double maxMb) {
  if (maxMb >= 1000) {
    return (v) => '${(v / 1024).toStringAsFixed(1)} GB';
  }
  return (v) => '${formatNumber(v)} MB';
}

/// Distance of [value] from the [leader] of its column: "−25%" when more is
/// better ("89× behind" once the value is under 5% of the leader, where a
/// percentage would round to a misleading "−100%"), "2.1× slower" /
/// "2.1× more" when less is better, "" when equal or undefined.
String gapToLeader(Metric metric, double value, double leader) {
  if (formatMetricShort(metric, value) == formatMetricShort(metric, leader)) {
    return '';
  }
  if (metric.higherIsBetter) {
    if (leader <= 0) return '';
    if (value <= 0) return '';
    final share = value / leader;
    if (share < 0.05) return '${_times(leader / value)} behind';
    return '−${((1 - share) * 100).round()}%';
  }
  if (leader <= 0) return '';
  final x = value / leader;
  final word = metric.unit == Unit.ms ? 'slower' : 'more';
  return '${_times(x)} $word';
}

String _times(double x) => '${x >= 10 ? x.round() : x.toStringAsFixed(1)}×';

/// Bar length for [value] against the [best] of its group, 0..1, where a
/// longer bar is always better: value / best when more is better, best /
/// value when less is better. Every bar in the app uses this.
double barShare(Metric metric, double? value, double? best) {
  if (value == null || best == null) return 0;
  if (metric.higherIsBetter) {
    return best <= 0 ? 0 : (value / best).clamp(0.0, 1.0);
  }
  return value <= 0 ? 1 : (best / value).clamp(0.0, 1.0);
}

/// How far ahead [leader] is of [next]: "1.33×" (always ≥ 1).
String leadRatio(Metric metric, double leader, double next) {
  final r = metric.higherIsBetter
      ? (next <= 0 ? null : leader / next)
      : (leader <= 0 ? null : next / leader);
  if (r == null) return '';
  return '${r >= 10 ? r.round() : r.toStringAsFixed(2)}×';
}

/// Step rates for axis ticks: 250, 500, 1k, 1.5k, 64k.
String compactRps(num v) {
  if (v >= 1000) {
    final k = v / 1000;
    return '${k == k.roundToDouble() ? k.toInt() : k.toStringAsFixed(1)}k';
  }
  return '${v.round()}';
}

/// "2026-10-04_m2pro-10c-32g_3ae75a8_cea6" → "2026-10-04 · 3ae75a8".
String shortRunId(String id) {
  final p = id.split('_');
  return p.length >= 3 ? '${p[0]} · ${p[2]}' : id;
}
