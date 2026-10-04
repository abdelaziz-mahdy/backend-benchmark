import 'package:flutter/material.dart';

// Background & surface
const kBackground = Color(0xFF0D1117);
const kCardBg = Color(0xFF161B22);
const kCardBgRaised = Color(0xFF1C2330);
const kBorder = Color(0xFF30363D);
const kGridLine = Color(0xFF21262D);

// Text hierarchy
const kTextPrimary = Color(0xFFE6EDF3);
const kTextSecondary = Color(0xFFC9D1D9);
const kTextMuted = Color(0xFF8B949E);
const kTextDim = Color(0xFF6E7681);

// Accent colors
const kBlue = Color(0xFF58A6FF);
const kGreen = Color(0xFF3FB950);
const kOrange = Color(0xFFF78166);
const kYellow = Color(0xFFD29922);
const kTeal = Color(0xFF00BFA5);
const kPurple = Color(0xFFBB86FC);

// Layout
const kMaxContentWidth = 1280.0;
const kNarrow = 760.0;
const kRadius = 10.0;

/// Segmented buttons tinted blue when selected (Material 3 defaults to the
/// secondary color, which is green here).
final kSegmentedStyle = ButtonStyle(
  visualDensity: VisualDensity.compact,
  backgroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.selected)
        ? kBlue.withValues(alpha: 0.2)
        : Colors.transparent,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.selected) ? kTextPrimary : kTextMuted,
  ),
  side: const WidgetStatePropertyAll(BorderSide(color: kBorder)),
);

/// Text style for button labels and dropdowns: the theme's label style (which
/// carries the font family) at a given size. A bare TextStyle in a
/// ButtonStyle drops the family and falls back to the engine default.
TextStyle labelStyle(
  BuildContext context,
  double size, {
  FontWeight? weight,
  Color? color,
}) => Theme.of(context).textTheme.labelLarge!.copyWith(
  fontSize: size,
  fontWeight: weight,
  color: color,
);
