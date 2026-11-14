import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/plain.dart';
import '../../models/results.dart';
import '../../state/dashboard_state.dart';
import '../../utils/theme_constants.dart';
import '../../widgets/calm.dart';
import 'home_nav.dart';

/// The short answer: the main test with its answer and number bands, the
/// other kinds of work folded underneath, and where to go next.
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
        Semantics(header: true, child: Text(main.title, style: t.h2)),
        const SizedBox(height: 4),
        Text(main.what, style: t.muted),
        const SizedBox(height: 14),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Text(answerFor(mainResults), style: t.answer),
        ),
        const SizedBox(height: 18),
        BandList(
          key: ValueKey('bands-${run.id}-${main.id}'),
          run: run,
          test: main.id,
          results: mainResults,
          unit: unit,
          mine: state.selectedKey,
          onOpen: nav.open,
          topLine: true,
        ),
        const SizedBox(height: 10),
        Text(
          'Highest first. Select a name to see its number.'
          '${state.selectedKey != null && mainResults.any((r) => r.key == state.selectedKey) ? ' The outlined name is the framework you looked up.' : ''}',
          style: t.small,
        ),
        if (tests.length > 1) ...[
          const SizedBox(height: 34),
          Semantics(
            header: true,
            child: Text(
              'Other kinds of work',
              style: t.h2.copyWith(fontSize: 18),
            ),
          ),
          const SizedBox(height: 10),
          for (final (i, id) in tests.skip(1).indexed)
            Fold(
              key: ValueKey('other-${run.id}-$id'),
              title: testInfo(id).title,
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
                  BandList(
                    key: ValueKey('bands-${run.id}-$id'),
                    run: run,
                    test: id,
                    results: resultsFor(run, id),
                    unit: unit,
                    mine: state.selectedKey,
                    onOpen: nav.open,
                    lastLine: false,
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
              label: 'Look up one framework',
              onTap: () => nav.go(HomeView.one),
            ),
            CalmButton(
              label: 'See every number',
              onTap: () => nav.go(HomeView.all),
            ),
            CalmButton(
              label: 'Compare frameworks',
              onTap: () => nav.go(HomeView.compare),
            ),
          ],
        ),
      ],
    );
  }
}

/// The number bands of one test: each band's range, its frameworks as
/// chips, a note when the load tool was the limit, and an inline reveal
/// for the chip that is open (one per band).
class BandList extends StatefulWidget {
  final RunSummary run;
  final String test;
  final List<Result> results;
  final String unit;
  final String? mine;
  final void Function(String key) onOpen;
  final bool topLine;
  final bool lastLine;

  const BandList({
    super.key,
    required this.run,
    required this.test,
    required this.results,
    required this.unit,
    required this.mine,
    required this.onOpen,
    this.topLine = false,
    this.lastLine = true,
  });

  @override
  State<BandList> createState() => _BandListState();
}

class _BandListState extends State<BandList> {
  /// Open chip per band, by the band's lower bound.
  final Map<double, String> _open = {};

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final bands = bandsFor(widget.results);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 600;
        return Container(
          decoration: BoxDecoration(
            border: Border(
              top: widget.topLine ? BorderSide(color: p.line) : BorderSide.none,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, band) in bands.indexed)
                _band(
                  band,
                  wide,
                  t,
                  p,
                  last: i == bands.length - 1 && !widget.lastLine,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _band(Band band, bool wide, Txt t, Palette p, {required bool last}) {
    final openKey = _open[band.from];
    final open = band.members.where((r) => r.key == openKey).firstOrNull;
    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(band.label, style: t.num(18)),
        Text(widget.unit, style: t.small.copyWith(fontSize: 14, height: 1.2)),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in band.members)
              NameChip(
                key: ValueKey('chip-${widget.test}-${r.key}'),
                label: r.name,
                mine: r.key == widget.mine,
                expanded: r.key == openKey,
                onTap: () => setState(() {
                  if (_open[band.from] == r.key) {
                    _open.remove(band.from);
                  } else {
                    _open[band.from] = r.key;
                  }
                }),
              ),
          ],
        ),
        if (band.cappedNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(band.cappedNote, style: t.small),
          ),
        Semantics(
          liveRegion: true,
          child: open == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Reveal(
                    result: open,
                    all: widget.results,
                    test: widget.test,
                    unit: widget.unit,
                    onOpen: widget.onOpen,
                  ),
                ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: last ? BorderSide.none : BorderSide(color: p.line),
        ),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 190, child: label),
                const SizedBox(width: 20),
                Expanded(child: right),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [label, const SizedBox(height: 10), right],
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
            label: 'All results for ${result.name}',
            accent: true,
            onTap: () => onOpen(result.key),
          ),
        ],
      ),
    );
  }
}
