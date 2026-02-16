import 'package:flutter/material.dart';

class ServiceColors {
  static final Map<String, Color> _baseColors = {
    'python django sync': const Color(0xFF092E20),
    'python django async': const Color(0xFF0C4B33),
    'python fast api': const Color(0xFF009485),
    'go mux': const Color(0xFF00ADD8),
    'java spring boot': const Color(0xFF5382A1),
    'c_sharp dot net': const Color(0xFF67217A),
    'rust actix web': const Color(0xFFDEA584),
    'dart server pod': const Color(0xFF0175C2),
    'javascript express node': const Color(0xFF68A063),
    'javascript express bun': const Color(0xFFF0DB4F),
  };

  static Color getColor(String serviceName) {
    final isNoDb = serviceName.contains('no_db_test');
    final baseName = serviceName
        .replaceAll(' db_test', '')
        .replaceAll(' no_db_test', '')
        .trim();

    final baseColor = _baseColors[baseName] ?? Colors.grey;

    if (isNoDb) {
      return Color.fromARGB(
        baseColor.a.toInt(),
        (baseColor.r * 0.6).toInt(),
        (baseColor.g * 0.6).toInt(),
        (baseColor.b * 0.6).toInt(),
      );
    }

    return baseColor;
  }
}
