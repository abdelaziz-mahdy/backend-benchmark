// Easy-to-scan prose for the Method and History pages: a one-line lead,
// then bullets with one fact each, the key term in bold at the start, and
// colour keys drawn as swatches. Generous, fixed spacing so a page reads
// as short pieces instead of dense paragraphs.

import 'package:material_ui/material_ui.dart';

import '../utils/theme_constants.dart';
import 'calm.dart';

/// Space between sections of a page.
const kSectionGap = 32.0;

/// Space between bullets.
const kBulletGap = 10.0;

/// Body text of bullets and leads.
TextStyle proseStyle(BuildContext context) =>
    Txt.of(context).body.copyWith(fontSize: 16, height: 1.55);

/// One bullet: an optional bold [term] that starts it, then [text].
/// [leading] replaces the dot (a swatch, an icon, a flag).
class Point {
  final String? term;
  final String text;
  final Widget? leading;

  const Point(this.term, this.text, {this.leading});

  /// A bullet with no bold term.
  const Point.plain(this.text, {this.leading}) : term = null;
}

/// A list of [Point]s, [gap] apart.
class Points extends StatelessWidget {
  final List<Point> items;
  final double gap;

  /// Width of the leading column (dot, swatch or icon).
  final double lead;

  const Points(this.items, {super.key, this.gap = kBulletGap, this.lead = 22});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = proseStyle(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : gap),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: lead,
                  // Centres the marker on the first line of text.
                  height: s.fontSize! * s.height!,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child:
                        items[i].leading ??
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: p.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        if (items[i].term != null)
                          TextSpan(
                            text: '${items[i].term} ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        TextSpan(text: items[i].text),
                      ],
                    ),
                    style: s,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The one-line lead of a section, a little larger than the bullets.
class Lead extends StatelessWidget {
  final String text;

  const Lead(this.text, {super.key});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 680),
    child: Text(
      text,
      style: Txt.of(context).body.copyWith(fontSize: 17, height: 1.5),
    ),
  );
}

/// A heading with an accent icon before it.
class SubHead extends StatelessWidget {
  final IconData icon;
  final String text;
  final double size;

  const SubHead(this.icon, this.text, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: size + 3, color: p.accent),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text, style: Txt(p).h3.copyWith(fontSize: size)),
          ),
        ],
      ),
    );
  }
}

/// A small square of colour for a colour key.
class Swatch extends StatelessWidget {
  final Color color;

  /// Fill opacity; the outline is always drawn at full colour.
  final double fill;
  final double size;

  const Swatch(this.color, {super.key, this.fill = 1, this.size = 14});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withValues(alpha: fill),
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: color),
    ),
  );
}

/// A tinted box for a tip or the main takeaway, with an icon.
class NoteBox extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const NoteBox({super.key, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: p.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// One key fact: an icon, a small label, the value in bold and a detail.
class FactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String detail;

  const FactCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: p.accent),
              const SizedBox(width: 6),
              Flexible(child: Text(label, style: t.small)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: t.h3.copyWith(fontSize: 19)),
          const SizedBox(height: 4),
          Text(detail, style: t.small.copyWith(height: 1.45)),
        ],
      ),
    );
  }
}

/// The top of the Method and History pages: a way back, the title with
/// its icon, and a one-line lead.
class PageHead extends StatelessWidget {
  final IconData icon;
  final String title;
  final String lead;
  final VoidCallback onBack;

  const PageHead({
    super.key,
    required this.icon,
    required this.title,
    required this.lead,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pressable(
          onTap: onBack,
          radius: 6,
          semanticLabel: 'Back to the results',
          builder: (context, hovered) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back, size: 18, color: p.accent),
              const SizedBox(width: 6),
              Text(
                'Back to the results',
                style: t.body.copyWith(
                  fontSize: 15,
                  color: p.accent,
                  fontWeight: FontWeight.w700,
                  decoration: hovered ? TextDecoration.underline : null,
                  decorationColor: p.accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Row(
            children: [
              Icon(icon, size: 30, color: p.accent),
              const SizedBox(width: 10),
              Flexible(child: Text(title, style: t.h1.copyWith(fontSize: 30))),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Text(lead, style: t.answer),
        ),
      ],
    );
  }
}
