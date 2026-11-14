// Building blocks of the home page, following the approved design: quiet
// type, hairlines, pill chips, outlined buttons, folds that open in place,
// and a visible focus ring for keyboard users.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/theme_constants.dart';

// ------------------------------------------------------------------- type

/// The design's type scale, coloured from the palette.
class Txt {
  final Palette p;

  const Txt(this.p);

  factory Txt.of(BuildContext context) => Txt(context.palette);

  TextStyle get body => TextStyle(
    fontFamily: kFontSans,
    fontSize: 17,
    height: 1.5,
    color: p.text,
  );
  TextStyle get muted => body.copyWith(color: p.muted);
  TextStyle get small => body.copyWith(fontSize: 14.5, color: p.muted);
  TextStyle get smallText => body.copyWith(fontSize: 15.5);
  TextStyle get h1 => body.copyWith(
    fontSize: 27,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.27,
  );
  TextStyle get h2 =>
      body.copyWith(fontSize: 21, height: 1.25, fontWeight: FontWeight.w700);
  TextStyle get h3 =>
      body.copyWith(fontSize: 17, height: 1.3, fontWeight: FontWeight.w700);
  TextStyle get answer => body.copyWith(fontSize: 19, height: 1.45);
  TextStyle num(double size, {FontWeight weight = FontWeight.w700}) =>
      body.copyWith(
        fontSize: size,
        height: 1.2,
        fontWeight: weight,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

// --------------------------------------------------------------- pressable

/// A tappable area with the design's affordances: Enter/Space activate it,
/// a 3 px focus ring shows for keyboard focus only, the pointer becomes a
/// hand, and it is at least [minHeight] tall.
class Pressable extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool hovered) builder;
  final double radius;
  final double minHeight;
  final double? minWidth;
  final String? semanticLabel;
  final bool? selected;
  final bool? expanded;
  final bool button;
  final FocusNode? focusNode;

  const Pressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.radius = 8,
    this.minHeight = 44,
    this.minWidth,
    this.semanticLabel,
    this.selected,
    this.expanded,
    this.button = true,
    this.focusNode,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = widget.onTap != null;
    return Semantics(
      button: widget.button,
      enabled: enabled,
      selected: widget.selected,
      expanded: widget.expanded,
      label: widget.semanticLabel,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: widget.minHeight,
                  minWidth: widget.minWidth ?? 0,
                ),
                child: widget.builder(context, _hovered && enabled),
              ),
              if (_focused)
                Positioned(
                  left: -5,
                  top: -5,
                  right: -5,
                  bottom: -5,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(widget.radius + 5),
                        border: Border.all(color: p.focus, width: 3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ chips

/// A name chip. [mine] outlines the framework the reader looked up;
/// [expanded] fills it while its reveal is open.
class NameChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool mine;
  final bool? expanded;
  final String? semanticLabel;

  const NameChip({
    super.key,
    required this.label,
    required this.onTap,
    this.mine = false,
    this.expanded,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final open = expanded ?? false;
    return Pressable(
      onTap: onTap,
      radius: 999,
      expanded: expanded,
      semanticLabel:
          semanticLabel ??
          (mine ? '$label (the framework you looked up)' : label),
      builder: (context, hovered) => AnimatedContainer(
        duration: motion(context, 120),
        constraints: const BoxConstraints(minHeight: 44),
        padding: EdgeInsets.symmetric(horizontal: mine ? 12 : 13),
        decoration: BoxDecoration(
          color: open ? p.accent : p.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: open || mine || hovered ? p.accent : p.line,
            width: mine ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: Txt(p).body.copyWith(
                    fontSize: 15.5,
                    height: 1.2,
                    color: open ? p.accentInk : p.text,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- buttons

/// The design's outlined button.
class CalmButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// Accent outline (inside a reveal).
  final bool accent;

  /// Filled with the accent colour (the one main action).
  final bool filled;
  final String? semanticLabel;

  const CalmButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.accent = false,
    this.filled = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final enabled = onTap != null;
    final fg = filled ? p.accentInk : (enabled ? p.text : p.muted);
    return Pressable(
      onTap: onTap,
      radius: 10,
      semanticLabel: semanticLabel ?? label,
      builder: (context, hovered) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: filled
              ? p.accent
              : hovered
              ? p.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled || accent
                ? p.accent
                : enabled
                ? p.text
                : p.line,
          ),
        ),
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: Txt(
                    p,
                  ).body.copyWith(fontSize: 15.5, height: 1.2, color: fg),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An underlined text link that does something in the page.
class TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double size;

  const TextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.size = 14.5,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Pressable(
      onTap: onTap,
      radius: 4,
      semanticLabel: label,
      builder: (context, hovered) => Align(
        widthFactor: 1,
        child: ExcludeSemantics(
          child: Text(
            label,
            style: Txt(p).body.copyWith(
              fontSize: size,
              color: p.accent,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: p.accent,
              decorationThickness: hovered ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ folds

/// A fold like HTML's details/summary: a bold title (and an optional muted
/// line) that opens [child] in place. Closed by default unless [open].
class Fold extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyOpen;

  /// Draws a hairline above it (the first of a list).
  final bool topLine;
  final ValueChanged<bool>? onChanged;
  final double titleSize;

  /// Shown before the title, in the accent colour.
  final IconData? icon;

  const Fold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.initiallyOpen = false,
    this.topLine = false,
    this.onChanged,
    this.titleSize = 17,
  });

  @override
  State<Fold> createState() => _FoldState();
}

class _FoldState extends State<Fold> {
  late bool _open = widget.initiallyOpen;

  void _toggle() {
    setState(() => _open = !_open);
    widget.onChanged?.call(_open);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: widget.topLine ? BorderSide(color: p.line) : BorderSide.none,
          bottom: BorderSide(color: p.line),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Pressable(
            onTap: _toggle,
            radius: 6,
            expanded: _open,
            semanticLabel: [widget.title, ?widget.subtitle].join('. '),
            builder: (context, hovered) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.topLeft,
                          widthFactor: 1,
                          heightFactor: 1,
                          child: AnimatedRotation(
                            turns: _open ? 0.25 : 0,
                            duration: motion(context, 150),
                            child: CustomPaint(
                              size: const Size(9, 10),
                              painter: _Triangle(p.text),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (widget.icon != null) ...[
                                Icon(
                                  widget.icon,
                                  size: widget.titleSize + 2,
                                  color: p.accent,
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  widget.title,
                                  style: t.h3.copyWith(
                                    fontSize: widget.titleSize,
                                    decoration: hovered
                                        ? TextDecoration.underline
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.subtitle != null)
                            Text(
                              widget.subtitle!,
                              style: t.muted.copyWith(fontSize: 15.5),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class _Triangle extends CustomPainter {
  final Color color;

  _Triangle(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Triangle old) => old.color != color;
}

// ----------------------------------------------------------------- switch

/// The view switch: equal segments, the chosen one filled with the
/// text colour. Arrow keys move between segments.
class SegmentSwitch<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String label;

  /// Focus node per option, so the page can return focus to the switch.
  final Map<T, FocusNode>? focusNodes;

  /// An icon before each option's label.
  final Map<T, IconData>? icons;

  const SegmentSwitch({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.label,
    this.focusNodes,
    this.icons,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Semantics(
      container: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.line),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            // Two rows of two on a phone, one row otherwise.
            final perRow = c.maxWidth < 520 && options.length > 3
                ? 2
                : options.length;
            final w = (c.maxWidth - 4 * (perRow - 1)) / perRow;
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final (value, text) in options)
                  SizedBox(
                    width: w,
                    child: Pressable(
                      onTap: () => onSelected(value),
                      focusNode: focusNodes?[value],
                      selected: value == selected,
                      semanticLabel: text,
                      radius: 8,
                      builder: (context, hovered) {
                        final on = value == selected;
                        return Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: on
                                ? p.text
                                : hovered
                                ? p.bg
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ExcludeSemantics(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icons?[value] != null) ...[
                                  Icon(
                                    icons![value],
                                    size: 19,
                                    color: on ? p.bg : p.muted,
                                  ),
                                  const SizedBox(width: 7),
                                ],
                                Flexible(
                                  child: Text(
                                    text,
                                    textAlign: TextAlign.center,
                                    style: t.body.copyWith(
                                      fontSize: 15.5,
                                      height: 1.2,
                                      color: on ? p.bg : p.text,
                                      fontWeight: on
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ select

/// A labelled drop-down in the design's select style.
class CalmSelect<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;
  final double maxWidth;

  const CalmSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.maxWidth = 360,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: t.small),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, minHeight: 46),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: p.text),
            ),
            child: Semantics(
              label: label,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<T>(
                  value: value,
                  isExpanded: true,
                  focusColor: Colors.transparent,
                  dropdownColor: p.surface,
                  iconEnabledColor: p.text,
                  borderRadius: BorderRadius.circular(10),
                  style: t.body,
                  itemHeight: 48,
                  items: [
                    for (final (v, text) in options)
                      DropdownMenuItem<T>(
                        value: v,
                        child: Text(text, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) onChanged(v);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- misc

/// Bulleted list in the small muted style.
class Bullets extends StatelessWidget {
  final List<String> items;
  final TextStyle? style;

  const Bullets(this.items, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final s = style ?? Txt.of(context).small;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 20, child: Text('•', style: s)),
                Expanded(child: Text(item, style: s)),
              ],
            ),
          ),
      ],
    );
  }
}

/// One framework among all of them on a line: small dots for the others,
/// a shaded band for its lowest-to-highest run, a large dot for it. Further
/// right is more. Decorative: the sentences under it say the same.
class DotStrip extends StatelessWidget {
  final double value;
  final double low;
  final double high;
  final List<double> others;
  final double max;

  const DotStrip({
    super.key,
    required this.value,
    required this.low,
    required this.high,
    required this.others,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          height: 22,
          width: double.infinity,
          child: CustomPaint(
            painter: _StripPainter(
              value: value,
              low: low,
              high: high,
              others: others,
              max: max,
              line: p.line,
              dot: p.dot,
              accent: p.accent,
              bg: p.bg,
            ),
          ),
        ),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  final double value, low, high, max;
  final List<double> others;
  final Color line, dot, accent, bg;

  _StripPainter({
    required this.value,
    required this.low,
    required this.high,
    required this.others,
    required this.max,
    required this.line,
    required this.dot,
    required this.accent,
    required this.bg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final w = size.width - inset * 2;
    double x(double v) => inset + (max <= 0 ? 0 : (v / max).clamp(0, 1) * w);
    canvas.drawRect(Rect.fromLTWH(0, 10, size.width, 2), Paint()..color = line);
    for (final o in others) {
      canvas.drawCircle(Offset(x(o), 11), 4, Paint()..color = dot);
    }
    final l = x(low), h = x(high);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(l, 7, (h - l) < 2 ? l + 2 : h, 15),
        const Radius.circular(4),
      ),
      Paint()..color = accent.withValues(alpha: 0.3),
    );
    canvas.drawCircle(Offset(x(value), 11), 8, Paint()..color = bg);
    canvas.drawCircle(Offset(x(value), 11), 6, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_StripPainter o) =>
      o.value != value ||
      o.low != low ||
      o.high != high ||
      o.max != max ||
      !listEquals(o.others, others) ||
      o.line != line ||
      o.accent != accent ||
      o.dot != dot ||
      o.bg != bg;
}

/// Copies [text] and confirms it.
void copyToClipboard(BuildContext context, String text, String done) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: Text(done),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

// ------------------------------------------------------------------ badge

/// A framework's language badge: its two-letter tag on its identity colour
/// (utils/colors.dart), with dark or light ink, whichever reads.
class LangBadge extends StatelessWidget {
  final Color color;
  final String tag;
  final double size;

  const LangBadge({
    super.key,
    required this.color,
    required this.tag,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    final ink = color.computeLuminance() > 0.28
        ? const Color(0xFF141614)
        : Colors.white;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          tag,
          style: TextStyle(
            color: ink,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// The icon for a test: both ways for the typical app, down for reading,
/// up for saving, a bolt for no database.
IconData testIcon(String id) => switch (id) {
  'db_mixed' => Icons.swap_vert,
  'db_read' => Icons.download_outlined,
  'db_write' => Icons.upload_outlined,
  'no_db' => Icons.bolt_outlined,
  _ => Icons.science_outlined,
};
