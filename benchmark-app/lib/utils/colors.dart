import 'package:flutter/material.dart';

class ServiceColors {
  // Bright, high-contrast colors that are easily distinguishable
  static final Map<String, Color> _baseColors = {
    'go mux': const Color(0xFF00B4D8), // Bright cyan
    'rust actix web': const Color(0xFFE85D26), // Rust orange
    'javascript express bun': const Color(0xFFF5A623), // Amber/gold
    'javascript express node': const Color(0xFF8BC34A), // Lime green
    'c_sharp dot net': const Color(0xFF9B59B6), // Purple
    'java spring boot': const Color(0xFF3F51B5), // Indigo
    'python fast api': const Color(0xFF00BFA5), // Teal
    'python django sync': const Color(0xFFE91E63), // Pink
    'python django async': const Color(0xFFFF5722), // Deep orange
    'dart server pod': const Color(0xFF2196F3), // Blue
  };

  static Color getColor(String serviceName) {
    final isNoDb = serviceName.contains('no_db_test');
    final baseName = serviceName
        .replaceAll(' db_test', '')
        .replaceAll(' no_db_test', '')
        .trim();

    final baseColor = _baseColors[baseName] ?? Colors.grey;

    if (isNoDb) {
      // Lighter variant for no_db — shift toward white by 40%
      final r = (baseColor.r * 255).round();
      final g = (baseColor.g * 255).round();
      final b = (baseColor.b * 255).round();
      return Color.fromARGB(
        255,
        r + ((255 - r) * 0.4).toInt(),
        g + ((255 - g) * 0.4).toInt(),
        b + ((255 - b) * 0.4).toInt(),
      );
    }

    return baseColor;
  }
}
