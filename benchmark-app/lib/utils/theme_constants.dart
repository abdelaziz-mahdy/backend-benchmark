import 'package:material_ui/material_ui.dart';

// "Race telemetry" tokens. One signal colour (lime) means leader / best /
// selected and nothing else; amber is reserved for result markers, red for
// the latency SLO and failed steps. Framework identity colours (colors.dart)
// never reuse these three.

// Track and surfaces
const kBackground = Color(0xFF0A0C10); // the track
const kCardBg = Color(0xFF12161D); // asphalt
const kCardBgRaised = Color(0xFF1A1F28); // kerb
const kBorder = Color(0x1AFFFFFF); // hairline, 10% white
const kBorderStrong = Color(0x33FFFFFF); // inputs and outlined controls
const kGridLine = Color(0x0FFFFFFF); // chart and row rules

// Text. Every colour below is at least 4.5:1 on kCardBg (WCAG AA).
const kTextPrimary = Color(0xFFECEFF4);
const kTextSecondary = Color(0xFFB4BCC8);
const kTextMuted = Color(0xFF8F98A8);
const kTextDim = Color(0xFF7F8899);

// Semantic accents
const kSignal = Color(0xFFC8F560); // phosphor lime: leader, best, selected
const kSignalInk = Color(0xFF0A0C10); // text on lime
const kAmber = Color(0xFFFFB020); // markers: capped, noisy, restarted
const kRedline = Color(0xFFFF4D4D); // SLO and failed steps

// Layout
const kMaxContentWidth = 1280.0;
const kNarrow = 760.0;
const kRadius = 12.0;

// Type. Bundled fonts (pubspec.yaml), so nothing loads at runtime.
const kFontSans = 'Roboto';
const kFontDisplay = 'RobotoCondensed';
const kFontMono = 'RobotoMono';

/// Numbers: monospaced with tabular figures, so columns line up.
TextStyle mono(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = kTextPrimary,
  double? height,
  double? letterSpacing,
}) => TextStyle(
  fontFamily: kFontMono,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Headlines: condensed bold, like a timing board.
TextStyle display(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = kTextPrimary,
  double? height = 1.1,
  double letterSpacing = 0,
}) => TextStyle(
  fontFamily: kFontDisplay,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// Small caps labels ("NO DB", "SHOWING"). Pass the text already upper-cased.
TextStyle caps(
  double size, {
  Color color = kTextMuted,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 1.2,
}) => TextStyle(
  fontFamily: kFontDisplay,
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
);

/// Body text in the sans family.
TextStyle body(
  double size, {
  Color color = kTextSecondary,
  FontWeight weight = FontWeight.w400,
  double? height,
}) => TextStyle(
  fontFamily: kFontSans,
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
);

/// Segmented buttons: kerb fill and lime text when selected.
final kSegmentedStyle = ButtonStyle(
  visualDensity: VisualDensity.compact,
  backgroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.selected)
        ? kSignal.withValues(alpha: 0.14)
        : Colors.transparent,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.selected) ? kSignal : kTextMuted,
  ),
  side: const WidgetStatePropertyAll(BorderSide(color: kBorderStrong)),
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

/// [ms] of motion, or none when the platform asks for reduced motion.
Duration motion(BuildContext context, int ms) =>
    MediaQuery.maybeDisableAnimationsOf(context) == true
    ? Duration.zero
    : Duration(milliseconds: ms);

/// Whether the platform asks for reduced motion.
bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) == true;
