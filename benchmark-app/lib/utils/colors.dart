import 'package:flutter/material.dart';

/// Stable, distinguishable color per backend key.
class BackendColors {
  static const _known = {
    'go-mux': Color(0xFF00B4D8),
    'rust-actix-web': Color(0xFFE85D26),
    'javascript-express-bun': Color(0xFFF5A623),
    'javascript-express-node': Color(0xFF8BC34A),
    'c_sharp-dot-net': Color(0xFFB07CD8),
    'java-spring-boot': Color(0xFF7986CB),
    'python-fast-api': Color(0xFF00BFA5),
    'python-django-sync': Color(0xFFE91E63),
    'python-django-async': Color(0xFFFF7043),
    'dart-server-pod': Color(0xFF42A5F5),
    'java-foam3-embedded': Color(0xFFFFD54F),
    'java-foam3-postgres': Color(0xFFA1887F),
  };

  static const _fallback = [
    Color(0xFF4DD0E1),
    Color(0xFFAED581),
    Color(0xFFFFB74D),
    Color(0xFFF06292),
    Color(0xFF9575CD),
    Color(0xFF4DB6AC),
    Color(0xFFDCE775),
    Color(0xFF90A4AE),
  ];

  static Color of(String key) {
    final known = _known[key];
    if (known != null) return known;
    var hash = 0;
    for (final c in key.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return _fallback[hash % _fallback.length];
  }
}
