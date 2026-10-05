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
    Unit.rps => '${formatNumber(value)} req/s',
    Unit.ms => formatMs(value),
    Unit.percent => _percentShare(value),
    Unit.cpu => '${value.toStringAsFixed(0)}%',
    Unit.mb => formatMb(value),
    Unit.ratio => formatNumber(value),
  };
}

/// Value without unit, for dense table cells.
String formatMetricShort(Metric metric, double? value) {
  if (value == null) return '—';
  return switch (metric.unit) {
    Unit.ms => formatMs(value),
    Unit.percent => _percentShare(value),
    Unit.cpu => '${value.toStringAsFixed(0)}%',
    Unit.mb => formatMb(value),
    _ => formatNumber(value),
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
