import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'theme_constants.dart';

/// Framework identity: one hue family per language, siblings in a language
/// told apart by lightness. None of these is the lime, amber or red that
/// carry meaning elsewhere (theme_constants.dart).
class BackendColors {
  static const _known = {
    'rust-actix-web': Color(0xFFF2773A),
    'go-mux': Color(0xFF2FC6E0),
    'javascript-express-bun': Color(0xFFF472B6),
    'javascript-express-node': Color(0xFFFBB6D8),
    'c_sharp-dot-net': Color(0xFFBB22AA),
    'java-spring-boot': Color(0xFF7C93FF),
    'java-foam3-embedded': Color(0xFFB9C6FF),
    'java-foam3-postgres': Color(0xFF5468D4),
    'python-fast-api': Color(0xFF2EC4A0),
    'python-django-sync': Color(0xFF8DEBC6),
    'python-django-async': Color(0xFF13917A),
    'dart-server-pod': Color(0xFFD9A066),
  };

  /// Base hue of each language family, for frameworks not listed above.
  static const _language = {
    'rust': Color(0xFFF2773A),
    'go': Color(0xFF2FC6E0),
    'javascript': Color(0xFFF472B6),
    'typescript': Color(0xFFF472B6),
    'c_sharp': Color(0xFFBB22AA),
    'java': Color(0xFF7C93FF),
    'kotlin': Color(0xFF7C93FF),
    'python': Color(0xFF2EC4A0),
    'dart': Color(0xFFD9A066),
  };

  static const _fallback = [
    Color(0xFF4DD0E1),
    Color(0xFFE879F9),
    Color(0xFF9AA5FF),
    Color(0xFFF0ABFC),
    Color(0xFF67E8F9),
    Color(0xFFD8B4FE),
  ];

  static Color of(String key) {
    final known = _known[key];
    if (known != null) return known;
    for (final e in _language.entries) {
      if (key.startsWith('${e.key}-')) return e.value;
    }
    var hash = 0;
    for (final c in key.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return _fallback[hash % _fallback.length];
  }
}

/// Two-letter language tag for the monogram tile: "Rs", "Go", "C#".
String monogramOf(String language) => switch (language) {
  'rust' => 'Rs',
  'go' => 'Go',
  'javascript' => 'Js',
  'typescript' => 'Ts',
  'c_sharp' => 'C#',
  'java' => 'Jv',
  'kotlin' => 'Kt',
  'python' => 'Py',
  'dart' => 'Dt',
  'ruby' => 'Rb',
  'php' => 'Php',
  'elixir' => 'Ex',
  _ =>
    language.isEmpty
        ? '?'
        : language[0].toUpperCase() +
              (language.length > 1 ? language[1].toLowerCase() : ''),
};

String languageLabel(String l) => switch (l) {
  'c_sharp' => 'C#',
  'javascript' => 'JavaScript',
  _ => l.isEmpty ? l : l[0].toUpperCase() + l.substring(1),
};

/// A framework's identity colour for [p]: as is on dark, darkened on light
/// so the paler hues stay visible on the light surface.
Color identityColor(Palette p, String key) {
  final c = BackendColors.of(key);
  if (p.isDark) return c;
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness(math.min(hsl.lightness, 0.40)).toColor();
}
