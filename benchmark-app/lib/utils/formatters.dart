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
