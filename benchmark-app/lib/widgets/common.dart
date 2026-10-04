import 'package:flutter/material.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../utils/colors.dart';
import '../utils/theme_constants.dart';

/// Card with a title row, used for every section. The header always keeps
/// its 16 px inset; [fullBleed] lets the body run edge to edge (tables).
class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final bool fullBleed;

  const SectionCard({
    super.key,
    required this.title,
    this.subtitle,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            color: kTextMuted,
                            fontSize: 12,
                          ),
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

/// Back link plus a page title, at the top of every page but the home.
class PageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  const PageTitle({
    super.key,
    required this.title,
    this.subtitle,
    required this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('All frameworks'),
          style: TextButton.styleFrom(
            foregroundColor: kBlue,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// One row of scenario chips; the only place a scenario is picked.
class ScenarioChips extends StatelessWidget {
  final List<String> scenarios;
  final String? selected;
  final ValueChanged<String> onSelected;

  /// Scenarios that would show nothing (greyed, still selectable).
  final Set<String> empty;

  const ScenarioChips({
    super.key,
    required this.scenarios,
    required this.selected,
    required this.onSelected,
    this.empty = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 4),
          child: Text(
            'Scenario',
            style: TextStyle(color: kTextMuted, fontSize: 12),
          ),
        ),
        for (final s in scenarios)
          Tooltip(
            message: scenarioHelp(s),
            waitDuration: _tooltipDelay,
            child: ChoiceChip(
              label: Text(scenarioLabel(s)),
              selected: selected == s,
              onSelected: (_) => onSelected(s),
              labelStyle: TextStyle(
                fontSize: 12,
                color: selected == s
                    ? kTextPrimary
                    : (empty.contains(s) ? kTextDim : kTextMuted),
              ),
              selectedColor: kBlue.withValues(alpha: 0.2),
              backgroundColor: kBackground,
              side: BorderSide(color: selected == s ? kBlue : kBorder),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    );
  }
}

/// Centered, width-limited scrolling page body.
class PageBody extends StatelessWidget {
  final List<Widget> children;

  const PageBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pad = constraints.maxWidth < kNarrow ? 12.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: pad, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(height: 16),
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

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.help,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: kTextMuted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: accent ?? kTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: const TextStyle(color: kTextDim, fontSize: 11),
            ),
          ],
        ],
      ),
    );
    if (help == null) return tile;
    return Tooltip(message: help!, waitDuration: _tooltipDelay, child: tile);
  }
}

const _tooltipDelay = Duration(milliseconds: 300);

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

/// Colored dot + framework name (+ optional subtitle).
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
        ColorDot(color: BackendColors.of(backend.key)),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                backend.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: kTextPrimary,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showSubtitle && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: kTextDim, fontSize: 11),
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

/// Small pill used for warnings like "load-gen limit" or "unstable".
class Flag extends StatelessWidget {
  final String text;
  final String tooltip;
  final Color color;

  const Flag({
    super.key,
    required this.text,
    required this.tooltip,
    this.color = kYellow,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: _tooltipDelay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Flags for a result, empty when nothing is worth flagging.
List<Widget> resultFlags(BackendResult b, ScenarioResult? r) => [
  if (r != null && r.loadgenBound)
    const Flag(
      text: 'load-gen limit',
      tooltip:
          'k6 used most of its CPU at the top steps: the real limit may be '
          'higher than measured on this machine.',
      color: kBlue,
    ),
  if (r != null && r.unstable)
    Flag(
      text: '±${(r.spread * 100).toStringAsFixed(0)}%',
      tooltip:
          'Repetitions differed by more than 10% on the headline number; '
          'treat small differences with care.',
    ),
  if (b.notes != null) Flag(text: 'note', tooltip: b.notes!, color: kTextMuted),
];

/// Horizontal bar scaled to [max], with an optional min–max whisker.
class InlineBar extends StatelessWidget {
  final double? value;
  final double max;
  final double? low;
  final double? high;
  final Color color;
  final double height;

  const InlineBar({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.low,
    this.high,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        double x(double v) => max <= 0 ? 0 : (v / max).clamp(0, 1) * w;
        final v = value;
        return SizedBox(
          height: height + 4,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: kGridLine,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
              if (v != null)
                Container(
                  width: x(v),
                  height: height,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              if (low != null && high != null && high! > low!)
                Positioned(
                  left: x(low!),
                  width: (x(high!) - x(low!)).clamp(1, w),
                  child: Container(height: 2, color: kTextPrimary),
                ),
            ],
          ),
        );
      },
    );
  }
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

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: kBorder),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: kTextSecondary, fontSize: 14),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kTextMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
