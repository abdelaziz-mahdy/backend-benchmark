import 'package:material_ui/material_ui.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../utils/colors.dart';
import '../utils/theme_constants.dart';
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
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
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
                        Text(subtitle!, style: body(12.5, color: kTextMuted)),
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

  const PageTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    required this.onBack,
    this.trailing,
    this.leading,
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
          label: const Text('Leaderboard'),
          style: TextButton.styleFrom(
            foregroundColor: kSignal,
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
                        style: body(13, color: kTextMuted),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null && !narrow) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
        // Phones: actions under the title, so long names do not break.
        if (trailing != null && narrow) ...[
          const SizedBox(height: 10),
          trailing!,
        ],
      ],
    );
  }
}

/// Equal-width scenario tabs; the one place a scenario is picked on the
/// Details, Compare and History pages (and the phone leaderboard sort).
class ScenarioTabs extends StatelessWidget {
  final List<String> scenarios;
  final String? selected;
  final ValueChanged<String> onSelected;

  /// Scenarios that would show nothing (dimmed, still selectable).
  final Set<String> empty;

  /// Leading caps label, e.g. "Scenario" or "Rank by".
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
    final tabs = Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          for (final s in scenarios)
            Expanded(
              child: _Tab(
                label: scenarioLabel(s),
                help: scenarioHelp(s),
                selected: s == selected,
                dim: empty.contains(s),
                icon: s == selected ? selectedIcon : null,
                onTap: () => onSelected(s),
              ),
            ),
        ],
      ),
    );
    return Row(
      children: [
        if (label != null) ...[
          Text(label!.toUpperCase(), style: caps(10.5)),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: tabs,
          ),
        ),
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
    final color = selected ? kSignal : (dim ? kTextDim : kTextSecondary);
    return Tooltip(
      message: help,
      waitDuration: _tooltipDelay,
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: AnimatedContainer(
            duration: motion(context, 200),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? kCardBgRaised : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: selected
                    ? kSignal.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(
                      12.5,
                      color: color,
                      weight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 3),
                  Icon(icon, size: 13, color: kSignal),
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
        color: hero ? kCardBgRaised : kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(
          color: hero ? kSignal.withValues(alpha: 0.45) : kBorder,
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
              color: accent ?? kTextPrimary,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: mono(11.5, color: kTextMuted)),
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

/// Language monogram in the framework's identity colour: the mark that
/// stands for a framework in rows, chips, legends and headers.
class Monogram extends StatelessWidget {
  final BackendResult backend;
  final double size;

  const Monogram({super.key, required this.backend, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final color = BackendColors.of(backend.key);
    final text = monogramOf(backend.language);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(size * 0.26),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Text(
          text,
          style: mono(
            size * (text.length > 2 ? 0.34 : 0.42),
            weight: FontWeight.w700,
            color: color,
            height: 1,
          ),
        ),
      ),
    );
  }
}

/// Monogram + framework name (+ optional subtitle).
class BackendLabel extends StatelessWidget {
  final BackendResult backend;
  final bool showSubtitle;
  final double fontSize;

  const BackendLabel({
    super.key,
    required this.backend,
    this.showSubtitle = true,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = backend.subtitle;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Monogram(backend: backend, size: 24),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                backend.name,
                overflow: TextOverflow.ellipsis,
                style: body(
                  fontSize,
                  color: kTextPrimary,
                  weight: FontWeight.w600,
                ),
              ),
              if (showSubtitle && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: body(11.5, color: kTextDim),
                ),
            ],
          ),
        ),
      ],
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
  final Color color;
  final IconData? icon;

  const Flag({
    super.key,
    required this.text,
    required this.tooltip,
    this.color = kAmber,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
      color: kAmber,
      semanticLabel: marker.label,
    ),
  );
}

/// The markers of one result, side by side.
class MarkerIcons extends StatelessWidget {
  final ScenarioResult? result;
  final double size;

  const MarkerIcons(this.result, {super.key, this.size = 13});

  @override
  Widget build(BuildContext context) {
    final marks = Marker.of(result);
    if (marks.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in marks)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: MarkerIcon(m, size: size),
          ),
      ],
    );
  }
}

/// Every marker with its short meaning, plus the dash for "not measured".
class MarkerLegend extends StatelessWidget {
  final bool compact;

  const MarkerLegend({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    Widget item(Widget icon, String text) => Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.only(right: 5),
              child: icon,
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      style: body(compact ? 11.5 : 12, color: kTextMuted),
    );
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final m in Marker.values)
          item(
            Icon(m.icon, size: 13, color: kAmber),
            compact ? m.short : m.label,
          ),
        item(
          Text('—', style: mono(12, color: kTextDim)),
          compact ? 'Not run' : 'Not measured',
        ),
      ],
    );
  }
}

/// Flags for a result as labelled pills, empty when nothing is worth
/// flagging.
List<Widget> resultFlags(BackendResult b, ScenarioResult? r) => [
  if (r != null && r.loadgenBound)
    const Flag(
      text: 'capped',
      icon: Icons.speed,
      tooltip:
          'k6 used most of its CPU at the top steps: the real limit may be '
          'higher than measured on this machine.',
    ),
  if (r != null && r.unstable)
    Flag(
      text: '±${(r.spread * 100).toStringAsFixed(0)}%',
      icon: Icons.waves,
      tooltip:
          'Repetitions differed by more than 10% on the headline number; '
          'treat small differences with care.',
    ),
  if (r != null && r.restarts > 0)
    Flag(
      text: 'restarted ${r.restarts}×',
      icon: Icons.restart_alt,
      tooltip:
          'Stopped responding under overload and was restarted by the '
          'runner.',
    ),
  if (b.notes != null) Flag(text: 'note', tooltip: b.notes!, color: kTextMuted),
];

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
  final Color track;

  const LaneBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 6,
    this.stagger = 0,
    this.low,
    this.high,
    this.track = kGridLine,
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
            track: track,
            low: low,
            high: high,
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
  final double? low;
  final double? high;

  _LanePainter({
    required this.fraction,
    required this.color,
    required this.track,
    this.low,
    this.high,
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
        Paint()..color = kTextPrimary,
      );
    }
  }

  @override
  bool shouldRepaint(_LanePainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.low != low ||
      old.high != high;
}

class InfoIcon extends StatelessWidget {
  final String message;

  const InfoIcon(this.message, {super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    waitDuration: _tooltipDelay,
    child: const Padding(
      padding: EdgeInsets.only(left: 4),
      child: Icon(Icons.info_outline, size: 14, color: kTextDim),
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
          Icon(icon, size: 40, color: kTextDim),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: display(18, color: kTextPrimary),
          ),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: body(13, color: kTextMuted),
            ),
          ],
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

/// Chequered flag glyph for the wordmark: a 3 × 3 board, lime and track.
class FinishFlag extends StatelessWidget {
  final double size;

  const FinishFlag({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _FlagPainter()),
  );
}

class _FlagPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3;
    final lime = Paint()..color = kSignal;
    final dark = Paint()..color = kSignal.withValues(alpha: 0.18);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        canvas.drawRect(
          Rect.fromLTWH(c * cell, r * cell, cell, cell),
          (r + c).isEven ? lime : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FlagPainter oldDelegate) => false;
}
