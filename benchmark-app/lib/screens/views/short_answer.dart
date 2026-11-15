import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/plain.dart';
import '../../models/results.dart';
import '../../state/dashboard_state.dart';
import '../../utils/colors.dart';
import '../../utils/theme_constants.dart';
import '../../widgets/calm.dart';
import 'home_nav.dart';

/// Who's fastest: the main test with a bar and number per framework, the
/// other tests folded underneath, and where to go next. What each test
/// does sits behind an (i) by its name.
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
    final m = state.measure;
    final unit = m == Measure.load ? unitFor(state.headline, run) : m.label;
    final cores = appCoreCount(run);
    Widget bars(String id) {
      final rs = measureResults(run, id, m);
      if (rs.isEmpty) {
        return Text('Not measured in this test.', style: t.muted);
      }
      return SpeedBars(
        key: ValueKey('bars-${run.id}-$id'),
        test: id,
        results: rs,
        unit: unit,
        measure: m,
        cores: cores,
        // "What to show" above already names the numbers.
        showUnit: false,
        mine: state.selectedKey,
        onOpen: nav.open,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: MeasurePicker(run: run),
        ),
        const SizedBox(height: 22),
        TestHeading(id: main.id),
        const SizedBox(height: 12),
        bars(main.id),
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
              info: testInfo(id).what,
              topLine: i == 0,
              child: bars(id),
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

/// "What to show": the result, or another measure, for the bars and the
/// table of every number, with what it means behind an (i). Lists only
/// what the run measured.
class MeasurePicker extends StatelessWidget {
  final RunSummary run;

  const MeasurePicker({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final tests = testsOf(run);
    final options = [
      for (final x in Measure.values)
        if (x == state.measure ||
            tests.any((id) => measureResults(run, id, x).isNotEmpty))
          (x, x.title(run)),
    ];
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        CalmSelect<Measure>(
          label: 'What to show',
          value: state.measure,
          options: options,
          onChanged: state.setMeasure,
          maxWidth: 400,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InfoTip(measureMeaning(state.measure, run)),
        ),
      ],
    );
  }
}

/// A test's icon and name, with what it does behind an (i).
class TestHeading extends StatelessWidget {
  final String id;
  final TextStyle? style;

  /// [TestInfo.whatFor] for a framework without a database.
  final bool noDatabase;

  const TestHeading({
    super.key,
    required this.id,
    this.style,
    this.noDatabase = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final info = testInfo(id);
    final st = style ?? t.h2;
    return Semantics(
      header: true,
      child: Row(
        children: [
          Icon(testIcon(id), size: (st.fontSize ?? 20) + 2, color: p.accent),
          const SizedBox(width: 8),
          Flexible(child: Text(info.title, style: st)),
          if (info.what.isNotEmpty)
            InfoTip(info.whatFor(noDatabase: noDatabase)),
        ],
      ),
    );
  }
}

/// A result's number: "40,000", or "40,000+" at the testing tool's limit,
/// where the "+" says why on hover or tap.
class ResultNumber extends StatelessWidget {
  final Result result;
  final TextStyle style;

  const ResultNumber(this.result, {super.key, required this.style});

  @override
  Widget build(BuildContext context) {
    final n = Text(
      '${whole(result.value)}${result.capped ? '+' : ''}',
      style: style,
      textAlign: TextAlign.right,
    );
    if (!result.capped) return n;
    return Tooltip(
      message: "+ = it hit our testing tool's limit, so it may be faster.",
      triggerMode: TooltipTriggerMode.longPress,
      child: n,
    );
  }
}

/// One bar per framework, longest first: its language badge and name, a
/// bar whose length is its share of the fastest, and its number. Tapping a
/// row opens its range of tries and notes under it.
class SpeedBars extends StatefulWidget {
  final String test;
  final List<Result> results;
  final String unit;
  final String? mine;
  final void Function(String key) onOpen;

  /// What the numbers are: the result unless picked otherwise. For the
  /// others the lowest comes first and its number is formatted to match.
  final Measure measure;

  /// The app's processor cores, for the processor measure's share.
  final int cores;

  /// The unit's name above the numbers; off where a picker names it.
  final bool showUnit;

  /// Every result in the test, for the close calls and place in a bar's
  /// box when [results] shows only some of them; defaults to [results].
  final List<Result>? all;

  /// The framework whose page this is: its box offers no "More about" (it
  /// would only lead back to the same page).
  final String? page;

  const SpeedBars({
    super.key,
    required this.test,
    required this.results,
    required this.unit,
    required this.mine,
    required this.onOpen,
    this.measure = Measure.load,
    this.cores = 1,
    this.showUnit = true,
    this.all,
    this.page,
  });

  @override
  State<SpeedBars> createState() => _SpeedBarsState();
}

class _SpeedBarsState extends State<SpeedBars> {
  String? _open;
  final _reveal = GlobalKey(debugLabel: 'reveal');

  /// The open box is kept in the page's storage under this set of bars'
  /// key, so Back to this view finds it open as it was left.
  String? get _memory => switch (widget.key) {
    final ValueKey<String> k => 'open-bar-${k.value}',
    _ => null,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final id = _memory;
    if (id != null && _open == null) {
      final saved = PageStorage.maybeOf(
        context,
      )?.readState(context, identifier: id);
      if (saved is String) _open = saved;
    }
  }

  void _toggle(String key) {
    setState(() => _open = _open == key ? null : key);
    final id = _memory;
    if (id != null) {
      PageStorage.maybeOf(context)?.writeState(context, _open, identifier: id);
    }
    // Closing one box can move the tapped row up; keep its box in view.
    if (_open != null) bringIntoView(_reveal);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final m = widget.measure;
    final rs = m.higherIsBetter
        ? sortResults(widget.results)
        : ([...widget.results]..sort((a, b) {
            final c = a.value.compareTo(b.value);
            return c != 0 ? c : a.name.compareTo(b.name);
          }));
    if (rs.isEmpty) return const SizedBox.shrink();
    final max = rs.map((r) => r.value).reduce((a, b) => a > b ? a : b);
    final open = rs.where((r) => r.key == _open).firstOrNull;
    return LayoutBuilder(
      builder: (context, c) {
        // Phones put the name above its bar, so names are never cut off.
        final double? nameWidth = c.maxWidth >= 600 ? 200.0 : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showUnit)
              Padding(
                padding: const EdgeInsets.only(right: 36, bottom: 2),
                child: Text(
                  capFirst(widget.unit),
                  textAlign: TextAlign.right,
                  style: t.small.copyWith(fontSize: 13),
                ),
              ),
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
                      measure: m,
                      cores: widget.cores,
                      onOpen: r.key == widget.page ? null : widget.onOpen,
                    ),
                  ),
                ),
            ],
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
      semanticLabel: widget.measure != Measure.load
          ? '${r.name}, ${widget.measure.format(r.value, widget.cores)} '
                '${widget.unit.toLowerCase()}. Show its tries and notes.'
          : '${r.name}, '
                '${topGroup(widget.results, all: widget.all).any((x) => x.key == r.key) ? (topGroup(widget.results, all: widget.all).length > 1 ? 'tied for fastest' : 'the fastest') : '${asFast(share)} as the fastest'}. '
                '${numberText(r)} ${widget.unit}. Show its tries and notes.',
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
            final numberStyle = t.body.copyWith(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            );
            final number = SizedBox(
              width: 76,
              child: widget.measure == Measure.load
                  ? ResultNumber(r, style: numberStyle)
                  : Text(
                      widget.measure.format(r.value, widget.cores),
                      textAlign: TextAlign.right,
                      style: numberStyle,
                    ),
            );
            // Says the row opens: down when closed, up when open.
            final more = Icon(
              isOpen ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: hovered || isOpen ? p.accent : p.muted,
            );
            if (nameWidth == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: label),
                      number,
                      const SizedBox(width: 4),
                      more,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: bar,
                  ),
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: nameWidth, child: label),
                const SizedBox(width: 12),
                Expanded(child: bar),
                const SizedBox(width: 10),
                number,
                const SizedBox(width: 4),
                more,
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
  final Measure measure;
  final int cores;

  /// Opens the framework's page; null on that page itself.
  final void Function(String key)? onOpen;

  const Reveal({
    super.key,
    required this.result,
    required this.all,
    required this.test,
    required this.unit,
    required this.onOpen,
    this.measure = Measure.load,
    this.cores = 1,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final notes = result.backend.notes;
    final isResult = measure == Measure.load;
    String fmt(double v) => measure.format(v, cores);
    final sentences = [
      if (isResult)
        ...resultSentences(all, result)
      else
        runsSentence(result, fmt),
      ?notes,
    ];
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
                TextSpan(
                  text: isResult ? numberText(result) : fmt(result.value),
                ),
                TextSpan(
                  text: ' ${isResult ? unit : unit.toLowerCase()}',
                  style: t.smallText.copyWith(fontWeight: FontWeight.w400),
                ),
              ],
            ),
            style: t.num(28),
          ),
          const SizedBox(height: 6),
          Text(sentences.join(' '), style: t.smallText),
          if (onOpen case final open?) ...[
            const SizedBox(height: 12),
            CalmButton(
              label: 'More about ${result.name}',
              accent: true,
              onTap: () => open(result.key),
            ),
          ],
        ],
      ),
    );
  }
}
