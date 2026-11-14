import 'package:material_ui/material_ui.dart';

/// The colour tokens of the approved design (its `:root` blocks), one set
/// for light and one for dark. Read them with `context.palette`; the app
/// follows the system setting.
///
/// [warn] and [danger] are not in the design: they only mark failed load
/// steps and the latency limit inside the charts.
@immutable
class Palette extends ThemeExtension<Palette> {
  final Color bg;
  final Color surface;
  final Color text;
  final Color muted;
  final Color line;
  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color dot;
  final Color focus;
  final Color warn;
  final Color danger;
  final Brightness brightness;

  const Palette({
    required this.bg,
    required this.surface,
    required this.text,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.dot,
    required this.focus,
    required this.warn,
    required this.danger,
    required this.brightness,
  });

  static const light = Palette(
    bg: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF14181F),
    muted: Color(0xFF586270),
    line: Color(0xFFE0E4EA),
    accent: Color(0xFF0E6B5C),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE0F0EC),
    dot: Color(0xFFB4BBC5),
    focus: Color(0xFFB4530A),
    warn: Color(0xFF8A5A00),
    danger: Color(0xFFB42318),
    brightness: Brightness.light,
  );

  static const dark = Palette(
    bg: Color(0xFF0E1116),
    surface: Color(0xFF161A21),
    text: Color(0xFFE8EBF0),
    muted: Color(0xFFA0A8B4),
    line: Color(0xFF2A303A),
    accent: Color(0xFF6FD0BE),
    accentInk: Color(0xFF0B1A17),
    accentSoft: Color(0xFF16302B),
    dot: Color(0xFF4E5662),
    focus: Color(0xFFFFB561),
    warn: Color(0xFFE8B04A),
    danger: Color(0xFFFF7B72),
    brightness: Brightness.dark,
  );

  bool get isDark => brightness == Brightness.dark;

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension PaletteOf on BuildContext {
  /// The colour tokens of the current theme.
  Palette get palette => Theme.of(this).extension<Palette>() ?? Palette.light;
}

// Layout
const kMaxContentWidth = 1280.0;

/// Width of the home page column (the design's `.page`).
const kHomeWidth = 860.0;
const kNarrow = 760.0;
const kRadius = 12.0;

// Type. Bundled fonts (pubspec.yaml), so nothing loads at runtime.
// TODO(font): the design uses Public Sans; it is not bundled and
// downloading fonts is not approved, so the bundled Roboto stands in.
const kFontSans = 'Roboto';
const kFontDisplay = kFontSans;
const kFontMono = kFontSans;

/// Numbers: tabular figures, so columns line up. A null [color] takes the
/// surrounding text colour.
TextStyle mono(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color? color,
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

/// Headings.
TextStyle display(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color? color,
  double? height = 1.2,
  double letterSpacing = 0,
}) => TextStyle(
  fontFamily: kFontDisplay,
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
  letterSpacing: letterSpacing,
);

/// Small labels ("SCENARIO"). Pass the text already upper-cased.
TextStyle caps(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 0.8,
}) => TextStyle(
  fontFamily: kFontSans,
  fontSize: size,
  fontWeight: weight,
  color: color,
  letterSpacing: letterSpacing,
);

/// Body text in the sans family.
TextStyle body(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
  double? height,
}) => TextStyle(
  fontFamily: kFontSans,
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
);

/// Segmented buttons in the design's switch style: the selected segment is
/// filled with the text colour.
ButtonStyle segmentedStyle(Palette p) => ButtonStyle(
  visualDensity: VisualDensity.compact,
  backgroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.selected) ? p.text : p.surface,
  ),
  foregroundColor: WidgetStateProperty.resolveWith(
    (s) => s.contains(WidgetState.selected) ? p.bg : p.text,
  ),
  side: WidgetStatePropertyAll(BorderSide(color: p.line)),
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

/// The light and dark themes built from [Palette].
ThemeData buildTheme(Palette p) {
  // TODO(font): Public Sans in the design; bundled Roboto here.
  final base = ThemeData(brightness: p.brightness, fontFamily: kFontSans);
  final scheme = p.isDark
      ? ColorScheme.dark(
          surface: p.surface,
          primary: p.accent,
          onPrimary: p.accentInk,
          secondary: p.accent,
          onSecondary: p.accentInk,
          onSurface: p.text,
          outline: p.line,
        )
      : ColorScheme.light(
          surface: p.surface,
          primary: p.accent,
          onPrimary: p.accentInk,
          secondary: p.accent,
          onSecondary: p.accentInk,
          onSurface: p.text,
          outline: p.line,
        );
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: scheme,
    extensions: [p],
    textTheme: base.textTheme.apply(
      fontFamily: kFontSans,
      bodyColor: p.text,
      displayColor: p.text,
    ),
    dividerColor: p.line,
    focusColor: p.focus.withValues(alpha: 0.16),
    hoverColor: p.text.withValues(alpha: 0.04),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.3),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: p.accent),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: p.text,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(color: p.bg, fontSize: 13, fontFamily: kFontSans),
      constraints: const BoxConstraints(maxWidth: 320),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.text,
      contentTextStyle: TextStyle(color: p.bg, fontFamily: kFontSans),
    ),
  );
}
