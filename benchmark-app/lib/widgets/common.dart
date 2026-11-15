import 'package:material_ui/material_ui.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../models/tests.dart';
import '../utils/theme_constants.dart';
import 'calm.dart';
import 'motion.dart';

const _tooltipDelay = Duration(milliseconds: 300);

/// Card with a title row, used for every section. The header always keeps
/// its 16 px inset; [fullBleed] lets the body run edge to edge (tables).
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final Widget child;
  final bool fullBleed;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    required this.child,
    this.fullBleed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: context.palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.start,
              runSpacing: 8,
              spacing: 12,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (eyebrow != null) ...[
                        Text(eyebrow!.toUpperCase(), style: caps(10.5)),
                        const SizedBox(height: 3),
                      ],
                      Text(title, style: display(18)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: body(12.5, color: context.palette.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: fullBleed
                ? const EdgeInsets.only(bottom: 6)
                : const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Back link, an eyebrow, and a page title that wraps rather than
/// truncating; at the top of every page but the leaderboard.
class PageTitle extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget? trailing;
  final Widget? leading;

  /// Keep [trailing] beside the title on phones too (a small icon button).
  final bool inlineTrailing;

  const PageTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    required this.onBack,
    this.trailing,
    this.leading,
    this.inlineTrailing = false,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < kNarrow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Back to the results'),
          style: TextButton.styleFrom(
            foregroundColor: context.palette.accent,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            visualDensity: VisualDensity.compact,
            textStyle: labelStyle(context, 13, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (eyebrow != null)
                    Text(eyebrow!.toUpperCase(), style: caps(11)),
                  Text(
                    title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: display(narrow ? 24 : 30),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle!,
                        style: body(13, color: context.palette.muted),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null && (!narrow || inlineTrailing)) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
        // Phones: actions under the title, so long names do not break.
        if (trailing != null && narrow && !inlineTrailing) ...[
          const SizedBox(height: 10),
          trailing!,
        ],
      ],
    );
  }
}

/// Equal-width test tabs with plain names; on a phone they wrap two to a
/// row and a long name wraps instead of being cut off.
class ScenarioTabs extends StatelessWidget {
  final List<String> scenarios;
  final String? selected;
  final ValueChanged<String> onSelected;

  /// Tests that would show nothing (dimmed, still selectable).
  final Set<String> empty;

  /// A label above the tabs, e.g. "Test" or "Rank by".
  final String? label;

  /// Arrow on the selected tab, for a sort control.
  final IconData? selectedIcon;

  const ScenarioTabs({
    super.key,
    required this.scenarios,
    required this.selected,
    required this.onSelected,
    this.empty = const {},
    this.label,
    this.selectedIcon,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tabs = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final perRow = c.maxWidth < 520 && scenarios.length > 3
              ? 2
              : scenarios.length;
          final w = (c.maxWidth - 4 * (perRow - 1)) / perRow;
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final s in scenarios)
                SizedBox(
                  width: w,
                  child: _Tab(
                    label: testInfo(s).title,
                    help: scenarioHelp(s),
                    selected: s == selected,
                    dim: empty.contains(s),
                    icon: s == selected ? selectedIcon : null,
                    onTap: () => onSelected(s),
                  ),
                ),
            ],
          );
        },
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: Txt(
              p,
            ).body.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
        ],
        tabs,
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final String help;
  final bool selected;
  final bool dim;
  final IconData? icon;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.help,
    required this.selected,
    required this.dim,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.bg : (dim ? p.muted : p.text);
    return Tooltip(
      message: help,
      waitDuration: _tooltipDelay,
      child: Pressable(
        onTap: onTap,
        selected: selected,
        semanticLabel: label,
        radius: 8,
        builder: (context, hovered) => AnimatedContainer(
          duration: motion(context, 200),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
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
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Txt(p).body.copyWith(
                      fontSize: 15,
                      height: 1.2,
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 4),
                  Icon(icon, size: 15, color: p.bg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered, width-limited scrolling page body.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;

  const PageBody({super.key, required this.children, this.controller});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < kNarrow ? 16.0 : 28.0;
        return SingleChildScrollView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final String? help;
  final Color? accent;
  final bool hero;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.help,
    this.accent,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: hero ? context.palette.accentSoft : context.palette.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: hero
              ? context.palette.accent.withValues(alpha: 0.45)
              : context.palette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: caps(10.5)),
          const SizedBox(height: 6),
          Text(
            value,
            style: mono(
              hero ? 26 : 19,
              weight: FontWeight.w700,
              color: accent ?? context.palette.text,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: mono(11.5, color: context.palette.muted)),
          ],
        ],
      ),
    );
    if (help == null) return tile;
    return Tooltip(message: help!, waitDuration: _tooltipDelay, child: tile);
  }
}

/// Responsive grid of fixed-width tiles.
class TileGrid extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;

  const TileGrid({super.key, required this.children, this.minTileWidth = 170});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / minTileWidth).floor().clamp(
          1,
          children.length,
        );
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in children) SizedBox(width: width, child: c),
          ],
        );
      },
    );
  }
}

class ColorDot extends StatelessWidget {
  final Color color;
  final double size;

  const ColorDot({super.key, required this.color, this.size = 10});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Small pill used for flags like "capped" or "±15%".
class Flag extends StatelessWidget {
  final String text;
  final String tooltip;
  final Color? color;
  final IconData? icon;

  const Flag({
    super.key,
    required this.text,
    required this.tooltip,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.palette.warn;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(text.toUpperCase(), style: caps(10, color: color)),
        ],
      ),
    );
    if (tooltip.isEmpty) return pill;
    return Tooltip(message: tooltip, waitDuration: _tooltipDelay, child: pill);
  }
}

/// Result markers: what a number cannot tell on its own.
enum Marker {
  capped(
    Icons.speed,
    'Capped by the load generator',
    'Capped',
    'The load generator was the limit; the real number may be higher.',
  ),
  noisy(
    Icons.waves,
    'Noisy repetitions',
    'Noisy',
    'Repetitions differed by more than 10%; treat small differences with '
        'care.',
  ),
  restarted(
    Icons.restart_alt,
    'Restarted under overload',
    'Restarted',
    'Stopped responding under overload and was restarted.',
  );

  final IconData icon;
  final String label;
  final String short;
  final String meaning;

  const Marker(this.icon, this.label, this.short, this.meaning);

  static List<Marker> of(ScenarioResult? r) => [
    if (r != null && r.loadgenBound) capped,
    if (r != null && r.unstable) noisy,
    if (r != null && r.restarts > 0) restarted,
  ];
}

/// One marker as a small amber icon with a tooltip and a screen-reader label.
class MarkerIcon extends StatelessWidget {
  final Marker marker;
  final double size;

  const MarkerIcon(this.marker, {super.key, this.size = 13});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '${marker.label}: ${marker.meaning}',
    waitDuration: _tooltipDelay,
    child: Icon(
      marker.icon,
      size: size,
      color: context.palette.warn,
      semanticLabel: marker.label,
    ),
  );
}

/// Horizontal bar scaled to [max] that grows in, with an optional min–max
/// whisker.
class InlineBar extends StatelessWidget {
  final double? value;
  final double max;
  final double? low;
  final double? high;
  final Color color;
  final double height;
  final double stagger;

  const InlineBar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.low,
    this.high,
    this.height = 8,
    this.stagger = 0,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    final share = v == null || max <= 0 ? 0.0 : (v / max).clamp(0.0, 1.0);
    return LaneBar(
      fraction: share,
      color: color,
      height: height,
      stagger: stagger,
      low: low == null || max <= 0 ? null : (low! / max).clamp(0.0, 1.0),
      high: high == null || max <= 0 ? null : (high! / max).clamp(0.0, 1.0),
    );
  }
}

/// A bar of a given share of its track, with a rounded tip.
class LaneBar extends StatelessWidget {
  final double fraction;
  final Color color;
  final double height;
  final double stagger;
  final double? low;
  final double? high;
  final Color? track;

  /// A lime finish line at the end of the track (the ranked column).
  final bool finish;

  const LaneBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 6,
    this.stagger = 0,
    this.low,
    this.high,
    this.track,
    this.finish = false,
  });

  @override
  Widget build(BuildContext context) {
    return GrowFraction(
      fraction: fraction,
      stagger: stagger,
      builder: (context, f) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _LanePainter(
            fraction: f,
            color: color,
            track: track ?? context.palette.line.withValues(alpha: 0.6),
            mark: context.palette.accent,
            whisker: context.palette.text,
            low: low,
            high: high,
            finish: finish,
          ),
        ),
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;
  final Color mark;
  final Color whisker;
  final double? low;
  final double? high;
  final bool finish;

  _LanePainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.mark,
    required this.whisker,
    this.low,
    this.high,
    this.finish = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = track,
    );
    final w = size.width * fraction.clamp(0.0, 1.0);
    if (w > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, size.height), r),
        Paint()..color = color,
      );
    }
    if (finish) {
      canvas.drawRect(
        Rect.fromLTWH(size.width - 1.5, -3, 1.5, size.height + 6),
        Paint()..color = mark,
      );
    }
    final lo = low, hi = high;
    if (lo != null && hi != null && hi > lo) {
      final y = size.height / 2;
      canvas.drawRect(
        Rect.fromLTRB(
          lo * size.width,
          y - 1,
          (hi * size.width).clamp(lo * size.width + 1, size.width),
          y + 1,
        ),
        Paint()..color = whisker,
      );
    }
  }

  @override
  bool shouldRepaint(_LanePainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.mark != mark ||
      old.whisker != whisker ||
      old.low != low ||
      old.high != high ||
      old.finish != finish;
}

class InfoIcon extends StatelessWidget {
  final String message;

  const InfoIcon(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    waitDuration: _tooltipDelay,
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Icon(Icons.info_outline, size: 14, color: context.palette.muted),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 40, color: context.palette.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: display(18, color: context.palette.text),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: body(13, color: context.palette.muted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}
