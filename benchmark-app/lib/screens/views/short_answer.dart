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

  /// Every result in the test, for the close calls and place in a bar's
  /// box when [results] shows only some of them; defaults to [results].
  final List<Result>? all;

  /// Shows the "Longer bar = …" note under the bars.
  final bool legend;

  const SpeedBars({
    super.key,
    required this.test,
    required this.results,
    required this.unit,
    required this.mine,
    required this.onOpen,
    this.all,
    this.legend = true,
  });

  @override
  State<SpeedBars> createState() => _SpeedBarsState();
}

class _SpeedBarsState extends State<SpeedBars> {
  String? _open;
  final _reveal = GlobalKey(debugLabel: 'reveal');

  void _toggle(String key) {
    setState(() => _open = _open == key ? null : key);
    // Closing one box can move the tapped row up; keep its box in view.
    if (_open != null) bringIntoView(_reveal);
  }

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
            for (final r in rs) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _row(r, max, nameWidth, t, p),
              ),
              // The number opens right under the bar that was tapped.
              if (r.key == open?.key)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    key: _reveal,
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
                    child: Reveal(
                      result: r,
                      all: widget.all ?? widget.results,
                      test: widget.test,
                      unit: widget.unit,
                      onOpen: widget.onOpen,
                    ),
                  ),
                ),
            ],
            if (widget.legend)
              BarsNote(
                capped: anyCapped,
                mine:
                    widget.mine != null && rs.any((r) => r.key == widget.mine),
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
      onTap: () => _toggle(r.key),
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
            final bar = SpeedBar(share: share, color: color, capped: r.capped);
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
            label: 'More about ${result.name}',
            accent: true,
            onTap: () => onOpen(result.key),
          ),
        ],
      ),
    );
  }
}

/// The note under a set of bars: how to read them and how to get a number.
class BarsNote extends StatelessWidget {
  final bool capped;
  final bool mine;

  const BarsNote({super.key, this.capped = true, this.mine = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.straighten, size: 18, color: p.muted),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Longer bar = more traffic handled. Tap a bar for its number.'
              "${capped ? " Striped end = hit our testing tool's limit, so it may be faster." : ''}"
              '${mine ? ' The outlined row is the one you looked up.' : ''}',
              style: Txt(p).small,
            ),
          ),
        ],
      ),
    );
  }
}
