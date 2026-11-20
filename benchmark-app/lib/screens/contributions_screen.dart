import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/link.dart';

import '../models/contributions.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import '../widgets/calm.dart';
import '../widgets/common.dart' show EmptyState, TileGrid;
import '../widgets/prose.dart';
import '../widgets/site_frame.dart' show SiteFooter, SiteWidth;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Nov 18, 2026".
String contributionDate(DateTime d) =>
    '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// "1,600", "7,250", "1.57".
String _amount(double v) {
  if (v != v.roundToDouble()) return v.toString();
  final s = v.round().toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// "3,335", or "11.4k" from ten thousand up.
String starCount(int n) =>
    n >= 10000 ? '${(n / 1000).toStringAsFixed(1)}k' : _amount(n.toDouble());

/// What the benchmark changed in other projects: the problems it found and
/// the fixes it led to, newest first, each with its state and, where it
/// was measured, the numbers before and after.
class ContributionsScreen extends StatelessWidget {
  const ContributionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SiteWidth(
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHead(
                    icon: Icons.handshake_outlined,
                    title: 'Contributions',
                    lead:
                        'Problems this benchmark found in other projects, '
                        'and the fixes it led to. Newest first.',
                    onBack: () => state.setPage(DashboardPage.home),
                  ),
                  const SizedBox(height: kSectionGap),
                  FutureBuilder<List<Contribution>>(
                    future: state.contributions,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return EmptyState(
                          icon: Icons.error_outline,
                          title: 'Could not load the contributions',
                          message: '${snap.error}',
                          action: CalmButton(
                            label: 'Try again',
                            onTap: state.retryContributions,
                          ),
                        );
                      }
                      final list = snap.data;
                      if (list == null) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _List(list);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  final List<Contribution> items;

  const _List(this.items);

  @override
  Widget build(BuildContext context) {
    final links = [for (final c in items) ...c.links];
    final fixes = links.where((l) => l.kind != 'issue').toList();
    final merged = fixes.where((l) => l.state == LinkState.merged).length;
    final open = links.where((l) => l.state == LinkState.open).length;
    final repos = {for (final c in items) c.repo: c};
    final stars = repos.values.fold<int>(0, (sum, c) => sum + c.stars);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TileGrid(
          minTileWidth: 200,
          children: [
            FactCard(
              icon: Icons.merge,
              label: 'Fixes merged',
              value: '$merged of ${fixes.length}',
              detail: 'pull requests and changes so far',
            ),
            FactCard(
              icon: Icons.schedule,
              label: 'Still open',
              value: '$open',
              detail: 'issues and fixes waiting on review',
            ),
            FactCard(
              icon: Icons.star_outline,
              label: 'Projects',
              value: '${repos.length}',
              detail: '${starCount(stars)} GitHub stars between them',
            ),
          ],
        ),
        const SizedBox(height: kSectionGap),
        for (final c in items) ...[_Card(c), const SizedBox(height: 16)],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Contribution c;

  const _Card(this.c);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Repo(c),
              Text(contributionDate(c.date), style: t.small),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.title, style: t.h3.copyWith(fontSize: 19)),
          const SizedBox(height: 6),
          Text(c.summary, style: t.smallText.copyWith(height: 1.5)),
          if (c.numbers.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final n in c.numbers) ...[
              _Numbers(n),
              const SizedBox(height: 10),
            ],
            if (c.note != null)
              Text(c.note!, style: t.small.copyWith(fontSize: 13.5)),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final l in c.links) _LinkChip(l)],
          ),
        ],
      ),
    );
  }
}

/// The project's name and its stars, linking to the repository.
class _Repo extends StatelessWidget {
  final Contribution c;

  const _Repo(this.c);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Link(
      uri: Uri.parse(c.repoUrl),
      target: LinkTarget.blank,
      builder: (context, follow) => Pressable(
        onTap: follow,
        radius: 6,
        semanticLabel: '${c.project} on GitHub, ${c.stars} stars',
        builder: (context, hovered) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              c.project,
              style: t.body.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: p.accent,
                decoration: hovered ? TextDecoration.underline : null,
                decorationColor: p.accent,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.star_rounded, size: 16, color: p.warn),
            const SizedBox(width: 2),
            Text(
              starCount(c.stars),
              style: t.num(
                14,
                weight: FontWeight.w400,
              ).copyWith(color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// One measured number: before and after as two bars, and the change.
class _Numbers extends StatelessWidget {
  final BeforeAfter n;

  const _Numbers(this.n);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final top = n.before > n.after ? n.before : n.after;
    Widget bar(String label, double v, Color color, {bool bold = false}) => Row(
      children: [
        SizedBox(width: 52, child: Text(label, style: t.small)),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                height: 10,
                width: (c.maxWidth * v / top).clamp(3, c.maxWidth),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 96,
          child: Text(
            _amount(v),
            textAlign: TextAlign.right,
            style: t.num(15, weight: bold ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              n.label,
              style: t.smallText.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '${n.unit} · ${n.change}',
              style: t.small.copyWith(color: p.accent),
            ),
          ],
        ),
        const SizedBox(height: 4),
        bar('Before', n.before, p.line),
        const SizedBox(height: 3),
        bar('After', n.after, p.accent, bold: true),
      ],
    );
  }
}

/// An issue, pull request or change, with its state.
class _LinkChip extends StatelessWidget {
  final ContributionLink l;

  const _LinkChip(this.l);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final (icon, color, fill) = switch (l.state) {
      LinkState.merged => (Icons.merge, p.accent, p.accentSoft),
      LinkState.open => (Icons.radio_button_unchecked, p.text, p.surface),
      LinkState.closed => (Icons.block, p.muted, p.bg),
    };
    final who = l.by == null ? '' : ' by ${l.by}';
    return Link(
      uri: Uri.parse(l.url),
      target: LinkTarget.blank,
      builder: (context, follow) => Pressable(
        onTap: follow,
        radius: 999,
        semanticLabel: '${l.label}$who, ${l.state.label}',
        builder: (context, hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: hovered ? p.text : p.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              // Wraps inside the chip on a narrow phone rather than
              // overflowing it.
              Flexible(
                child: Text(
                  '${l.label}$who',
                  style: t.small.copyWith(color: p.text, fontSize: 14),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                l.state.label,
                style: t.small.copyWith(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
