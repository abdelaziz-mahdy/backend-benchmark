import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/plain.dart';
import '../../state/dashboard_state.dart';
import '../../utils/colors.dart';
import '../../utils/theme_constants.dart';
import '../../widgets/calm.dart';
import 'home_nav.dart';

/// Who's fastest: the main test with its answer in words and a bar per
/// framework, the other tests folded underneath, and where to go next.
class ShortAnswerView extends StatelessWidget {
  const ShortAnswerView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run!;
    final nav = HomeNav.of(context);
    final t = Txt.of(context);
    final tests = testsOf(run);
    if (tests.isEmpty) {
      return Text('This run has no results.', style: t.body);
    }
    final main = testInfo(tests.first);
    final mainResults = resultsFor(run, main.id);
    final unit = unitFor(state.headline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Row(
            children: [
              Icon(testIcon(main.id), size: 24, color: context.palette.accent),
              const SizedBox(width: 8),
              Flexible(child: Text(main.title, style: t.h2)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(main.what, style: t.muted),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Text(answerFor(mainResults), style: t.answer),
        ),
        const SizedBox(height: 18),
        SpeedBars(
          key: ValueKey('bars-${run.id}-${main.id}'),
          test: main.id,
          results: mainResults,
          unit: unit,
          mine: state.selectedKey,
          onOpen: nav.open,
        ),
        if (tests.length > 1) ...[
          const SizedBox(height: 34),
          Semantics(
            header: true,
            child: Text('Other tests', style: t.h2.copyWith(fontSize: 18)),
          ),
          const SizedBox(height: 10),
          for (final (i, id) in tests.skip(1).indexed)
            Fold(
              key: ValueKey('other-${run.id}-$id'),
              title: testInfo(id).title,
              icon: testIcon(id),
              subtitle: otherSummary(resultsFor(run, id), mainResults, main),
              topLine: i == 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      testInfo(id).what,
                      style: t.small.copyWith(fontSize: 15.5),
                    ),
                  ),
                  SpeedBars(
                    key: ValueKey('bars-${run.id}-$id'),
                    test: id,
                    results: resultsFor(run, id),
                    unit: unit,
                    mine: state.selectedKey,
                    onOpen: nav.open,
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 30),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            CalmButton(
              label: 'Find a framework',
              icon: Icons.search,
              onTap: () => nav.go(HomeView.one),
            ),
            CalmButton(
              label: 'See all results',
              icon: Icons.table_rows_outlined,
              onTap: () => nav.go(HomeView.all),
            ),
            CalmButton(
              label: 'Compare frameworks',
              icon: Icons.compare_arrows,
              onTap: () => nav.go(HomeView.compare),
            ),
          ],
        ),
      ],
    );
  }
}

/// One bar per framework, longest first: its language badge and name, and
/// a bar whose length is its share of the fastest. No numbers until a bar
/// is tapped; then its number, run range and notes open under the list.
class SpeedBars extends StatefulWidget {
  final String test;
  final List<Result> results;
  final String unit;
  final String? mine;
  final void Function(String key) onOpen;

  const SpeedBars({
    super.key,
    required this.test,
    required this.results,
    required this.unit,
    required this.mine,
    required this.onOpen,
  });

  @override
  State<SpeedBars> createState() => _SpeedBarsState();
}

class _SpeedBarsState extends State<SpeedBars> {
  String? _open;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final rs = sortResults(widget.results);
    if (rs.isEmpty) return const SizedBox.shrink();
    final max = rs.first.value;
    final open = rs.where((r) => r.key == _open).firstOrNull;
    final anyCapped = rs.any((r) => r.capped);
    return LayoutBuilder(
      builder: (context, c) {
        // Phones put the name above its bar, so names are never cut off.
        final double? nameWidth = c.maxWidth >= 600 ? 200.0 : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final r in rs)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _row(r, max, nameWidth, t, p),
              ),
            Semantics(
              liveRegion: true,
              child: open == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Reveal(
                        result: open,
                        all: widget.results,
                        test: widget.test,
                        unit: widget.unit,
                        onOpen: widget.onOpen,
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.straighten, size: 18, color: p.muted),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Longer bar = more traffic handled. Tap a bar for its '
                    'number.'
                    "${anyCapped ? " Striped end = hit our testing tool's limit, so it may be faster." : ''}"
                    '${widget.mine != null && rs.any((r) => r.key == widget.mine) ? ' The outlined row is the one you looked up.' : ''}',
                    style: t.small,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _row(Result r, double max, double? nameWidth, Txt t, Palette p) {
    final color = BackendColors.of(r.key);
    final share = max <= 0 ? 0.0 : (r.value / max).clamp(0.0, 1.0);
    final isOpen = r.key == _open;
    final mine = r.key == widget.mine;
    return Pressable(
      key: ValueKey('bar-${widget.test}-${r.key}'),
      onTap: () => setState(() => _open = isOpen ? null : r.key),
      expanded: isOpen,
      radius: 10,
      semanticLabel:
          '${r.name}, ${asFast(share)} as the fastest. '
          'Show its number.',
      builder: (context, hovered) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isOpen
              ? p.accentSoft
              : hovered
              ? p.surface
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: mine ? p.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Builder(
          builder: (context) {
            final label = Row(
              children: [
                LangBadge(color: color, tag: monogramOf(r.backend.language)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(fontSize: 15.5, height: 1.2),
                  ),
                ),
              ],
            );
            final bar = _Bar(share: share, color: color, capped: r.capped);
            if (nameWidth == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [label, const SizedBox(height: 6), bar],
              );
            }
            return Row(
              children: [
                SizedBox(width: nameWidth, child: label),
                const SizedBox(width: 12),
                Expanded(child: bar),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A rounded bar on a faint track; a capped result gets a striped end that
/// says "possibly longer".
class _Bar extends StatelessWidget {
  final double share;
  final Color color;
  final bool capped;

  const _Bar({required this.share, required this.color, required this.capped});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const stripe = 18.0;
    return LayoutBuilder(
      builder: (context, c) {
        final track = c.maxWidth - stripe - 2;
        final w = (track * share).clamp(4.0, track);
        final edge = Color.lerp(color, const Color(0xFF000000), 0.22)!;
        return SizedBox(
          height: 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: track,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.line.withValues(alpha: p.isDark ? 0.9 : 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: motion(context, 400),
                curve: Curves.easeOutCubic,
                left: 0,
                top: 0,
                bottom: 0,
                width: w,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: p.isDark ? null : Border.all(color: edge, width: 1),
                  ),
                ),
              ),
              if (capped)
                Positioned(
                  left: w + 2,
                  top: 3,
                  bottom: 3,
                  width: stripe - 2,
                  child: CustomPaint(painter: _Stripes(color)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Stripes extends CustomPainter {
  final Color color;

  _Stripes(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.7);
    for (var x = 0.0; x < size.width; x += 5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 0, 2.5, size.height),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Stripes old) => old.color != color;
}

/// What a chip opens: the number, the run range, the close call or the
/// load-tool limit, the framework's own note, and a way to its profile.
class Reveal extends StatelessWidget {
  final Result result;
  final List<Result> all;
  final String test;
  final String unit;
  final void Function(String key) onOpen;

  const Reveal({
    super.key,
    required this.result,
    required this.all,
    required this.test,
    required this.unit,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final notes = result.backend.notes;
    final sentences = [...resultSentences(all, result), ?notes];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: result.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' · ${testInfo(test).short}'),
              ],
            ),
            style: t.smallText,
          ),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: numberText(result)),
                TextSpan(
                  text: ' $unit',
                  style: t.smallText.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            ),
            style: t.num(28),
          ),
          const SizedBox(height: 6),
          Text(sentences.join(' '), style: t.smallText),
          const SizedBox(height: 12),
          CalmButton(
            label: 'All results for ${result.name}',
            accent: true,
            onTap: () => onOpen(result.key),
          ),
        ],
      ),
    );
  }
}
