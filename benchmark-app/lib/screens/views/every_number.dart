import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/plain.dart';
import '../../models/results.dart';
import '../../state/dashboard_state.dart';
import '../../utils/colors.dart';
import '../../utils/theme_constants.dart';
import '../../widgets/calm.dart';
import 'home_nav.dart';

/// Rows of the Every number table for [state]: sorted by the chosen test
/// column (or by name), missing values last, name order among equals.
List<BackendResult> everyNumberRows(DashboardState state) {
  final run = state.run;
  if (run == null) return const [];
  final rows = [...run.backends];
  final test = state.sortTest;
  final dir = state.sortDesc ? -1 : 1;
  if (test == null || test == DashboardState.sortByName) {
    rows.sort((a, b) => -dir * a.name.compareTo(b.name));
    return rows;
  }
  double? v(BackendResult b) {
    final r = b.scenarios[test];
    return r == null ? null : state.measure.value(r, state.headline);
  }

  rows.sort((a, b) {
    final va = v(a), vb = v(b);
    if (va == null && vb == null) return a.name.compareTo(b.name);
    if (va == null) return 1;
    if (vb == null) return -1;
    final c = dir * va.compareTo(vb);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return rows;
}

/// Every number: every framework in every test, sortable by any test, for
/// any of five measures.
class EveryNumberView extends StatelessWidget {
  const EveryNumberView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run!;
    final t = Txt.of(context);
    final tests = testsOf(run);
    final m = state.measure;
    final byName = state.sortTest == DashboardState.sortByName;
    final sortLabel = byName
        ? 'name, ${state.sortDesc ? 'A to Z' : 'Z to A'}'
        : '${testInfo(state.sortTest ?? tests.first).short}, '
              '${state.sortDesc ? 'highest first' : 'lowest first'}';
    final rows = everyNumberRows(state);
    final anyCapped =
        m == Measure.load &&
        run.backends.any((b) => b.scenarios.values.any((r) => r.loadgenBound));
    final cores = appCoreCount(run);
    final legacy = run.isLegacy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('All results', style: t.h2)),
        const SizedBox(height: 4),
        Text(
          'All ${run.backends.length} frameworks across the '
          '${kindsOfWork(tests.length)}.',
          style: t.muted,
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 24,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            CalmSelect<Measure>(
              label: 'What to show',
              value: m,
              options: [
                for (final x in Measure.values)
                  (x, x == Measure.load ? '${x.label} (the result)' : x.label),
              ],
              onChanged: state.setMeasure,
            ),
            if (m == Measure.load && !legacy)
              _Check(
                value: state.showRange,
                label: 'Also show the lowest and highest try',
                onChanged: state.setShowRange,
              ),
          ],
        ),
        const SizedBox(height: 14),
        Semantics(
          liveRegion: true,
          child: Text(
            'Sorted by $sortLabel. Select a column heading to sort by it.',
            style: t.small,
          ),
        ),
        const SizedBox(height: 8),
        _Table(state: state, tests: tests, rows: rows, cores: cores),
        const SizedBox(height: 12),
        Bullets([
          if (m == Measure.load) ...[
            if (legacy)
              'Each number is the average requests a second during the old '
                  'test. Higher is better.'
            else
              'Each number is requests a second: the busiest rate we sent '
                  'that the framework kept up with, while 99 of every 100 '
                  'replies came back '
                  '${sloPhrase(run)}, with few errors, and it kept up with at '
                  'least ${keptUp(run)} of the requests sent. Higher is '
                  'better.',
            if (anyCapped)
              'A plus sign (+) means the framework reached the most our testing '
                  'tool could send. Its real figure may be higher.',
          ] else ...[
            '${m.label}: ${m == Measure.processor ? 'how much of its ${numberWord(cores)} processor ${cores == 1 ? 'core' : 'cores'} the framework used' : m.meaning}.',
            if (legacy)
              'Each framework was measured during the old test, which sent '
                  'the same traffic to every framework.'
            else
              'Each framework was measured at its own top load (its '
                  'requests-a-second result), so this is not a like-for-like '
                  'race.',
            if (m == Measure.typical || m == Measure.slow)
              '"ms" means milliseconds. 1,000 ms is one second.',
          ],
          if (rows.any(
            (b) => tests.any(
              (s) =>
                  b.scenarios[s] == null ||
                  m.value(b.scenarios[s]!, state.headline) == null,
            ),
          ))
            'A dash means the framework was not measured in that test.',
          'Select a framework name to see everything about it. The last '
              'column adds it to Compare (up to ${DashboardState.maxCompare}).',
          if (state.selectedKey != null &&
              run.backend(state.selectedKey!) != null)
            'The row marked on the left is the one you looked up.',
        ]),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;

  const _Check({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return MergeSemantics(
      child: Pressable(
        onTap: () => onChanged(!value),
        button: false,
        radius: 6,
        builder: (context, hovered) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 46,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: p.accent,
                checkColor: p.accentInk,
                side: BorderSide(color: p.text, width: 1.5),
              ),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label, style: Txt(p).body.copyWith(fontSize: 15.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  final DashboardState state;
  final List<String> tests;
  final List<BackendResult> rows;
  final int cores;

  const _Table({
    required this.state,
    required this.tests,
    required this.rows,
    required this.cores,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final nav = HomeNav.of(context);
    final m = state.measure;
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth <= 480;
        final size = narrow ? 13.0 : 14.5;
        final cellPad = EdgeInsets.symmetric(
          vertical: 10,
          horizontal: narrow ? 4 : 8,
        );
        final cell = t.body.copyWith(
          fontSize: size,
          height: 1.3,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
        final sorted = state.sortTest;
        Widget head(String key, String text, {bool left = false}) {
          final on = sorted == key;
          final dir = key == DashboardState.sortByName
              ? (state.sortDesc ? 'A to Z' : 'Z to A')
              : (state.sortDesc ? 'highest first' : 'lowest first');
          return Pressable(
            onTap: () => state.sortBy(key),
            radius: 6,
            semanticLabel: on
                ? '$text, sorted $dir. Select to reverse.'
                : 'Sort by $text',
            builder: (context, hovered) => Container(
              alignment: left ? Alignment.bottomLeft : Alignment.bottomRight,
              padding: EdgeInsets.fromLTRB(
                left ? (narrow ? 10 : 12) : 4,
                8,
                4,
                8,
              ),
              child: Text(
                text,
                textAlign: left ? TextAlign.left : TextAlign.right,
                style: cell.copyWith(
                  fontSize: narrow ? 11 : 14,
                  height: 1.2,
                  color: on ? p.text : p.muted,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                  decoration: on || hovered ? TextDecoration.underline : null,
                  decorationColor: on ? p.text : p.muted,
                ),
              ),
            ),
          );
        }

        String? range(BackendResult b, String test) {
          final r = b.scenarios[test];
          final s = r == null ? null : state.headline.stat(r);
          if (s == null) return null;
          return whole(s.min) == whole(s.max)
              ? 'all tries equal'
              : '${whole(s.min)} to ${whole(s.max)}';
        }

        // The longest result in each test, for the bars under the numbers.
        final most = {
          for (final s in tests)
            s: rows
                .map((b) => b.scenarios[s])
                .whereType<ScenarioResult>()
                .map((r) => m.value(r, state.headline) ?? 0)
                .fold(0.0, (a, v) => v > a ? v : a),
        };
        final table = Table(
          columnWidths: {
            0: FlexColumnWidth(narrow ? 1.6 : 1.5),
            for (var i = 1; i <= tests.length; i++) i: const FlexColumnWidth(1),
            tests.length + 1: FixedColumnWidth(narrow ? 34 : 68),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.top,
          children: [
            TableRow(
              // Every heading sits on the same baseline, at the bottom.
              children: [
                for (final cell in [
                  head(DashboardState.sortByName, 'Framework', left: true),
                  for (final s in tests) head(s, testInfo(s).short),
                ])
                  TableCell(
                    verticalAlignment: TableCellVerticalAlignment.bottom,
                    child: cell,
                  ),
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.bottom,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                    child: ExcludeSemantics(
                      child: narrow
                          ? Icon(Icons.compare_arrows, size: 16, color: p.muted)
                          : Text(
                              'Compare',
                              textAlign: TextAlign.center,
                              style: cell.copyWith(
                                fontSize: 12,
                                color: p.muted,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            for (final b in rows)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.line)),
                ),
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: b.key == state.selectedKey
                              ? p.accent
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    padding: EdgeInsets.only(left: narrow ? 7 : 9),
                    child: Pressable(
                      onTap: () => nav.open(b.key),
                      radius: 4,
                      semanticLabel: 'Everything about ${b.name}',
                      builder: (context, hovered) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Phones keep the width for the name; the bars
                            // under the numbers carry its colour.
                            if (!narrow) ...[
                              LangBadge.of(b.key, b.language, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                b.name,
                                style: cell.copyWith(
                                  height: 1.25,
                                  decoration: TextDecoration.underline,
                                  decorationColor: hovered ? p.text : p.line,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  for (final s in tests)
                    Padding(
                      padding: cellPad,
                      child: _value(
                        b,
                        s,
                        m,
                        cell,
                        p,
                        range(b, s),
                        narrow,
                        most[s]!,
                      ),
                    ),
                  _CompareToggle(state: state, backend: b),
                ],
              ),
          ],
        );
        return Semantics(
          label: 'Table of results',
          container: true,
          explicitChildNodes: true,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.line),
            ),
            child: c.maxWidth < 330
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: 330, child: table),
                  )
                : table,
          ),
        );
      },
    );
  }

  Widget _value(
    BackendResult b,
    String test,
    Measure m,
    TextStyle cell,
    Palette p,
    String? range,
    bool narrow,
    double most,
  ) {
    final r = b.scenarios[test];
    final v = r == null ? null : m.value(r, state.headline);
    final on = state.sortTest == test;
    final style = cell.copyWith(fontWeight: on ? FontWeight.w700 : null);
    if (v == null) {
      return Text(
        '—',
        textAlign: TextAlign.right,
        style: style,
        semanticsLabel: 'not measured',
      );
    }
    final capped = m == Measure.load && r!.loadgenBound;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Never wraps: a long value shrinks to fit its column instead.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '${m.format(v, cores)}${capped ? '+' : ''}',
            textAlign: TextAlign.right,
            maxLines: 1,
            style: style,
            semanticsLabel: '${m.format(v, cores)}${capped ? ' or more' : ''}',
          ),
        ),
        // A thin bar in the framework's colour: its share of the column's
        // best, so the column can be read by length as well as number.
        if (m == Measure.load && most > 0)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: ExcludeSemantics(
              child: SpeedBar(
                share: (v / most).clamp(0.0, 1.0),
                color: BackendColors.of(b.key),
                capped: capped,
                height: 5,
              ),
            ),
          ),
        if (m == Measure.load && state.showRange && range != null)
          Text(
            range,
            textAlign: TextAlign.right,
            softWrap: narrow,
            style: cell.copyWith(
              fontSize: narrow ? 12 : 12.5,
              color: p.muted,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }
}

/// The last column: add the framework to Compare, or take it out.
class _CompareToggle extends StatefulWidget {
  final DashboardState state;
  final BackendResult backend;

  const _CompareToggle({required this.state, required this.backend});

  @override
  State<_CompareToggle> createState() => _CompareToggleState();
}

class _CompareToggleState extends State<_CompareToggle> {
  final _tip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final backend = widget.backend;
    final p = context.palette;
    final on = state.compareKeys.contains(backend.key);
    final can = state.canAddCompare(backend.key);
    return Tooltip(
      key: _tip,
      message: on
          ? 'Remove from compare'
          : can
          ? 'Add to compare'
          : 'Compare holds up to ${DashboardState.maxCompare}. Remove one '
                'there to add this one.',
      child: Pressable(
        // When Compare is full a tap still answers, right at the button.
        onTap: can
            ? () => state.toggleCompare(backend.key)
            : () => _tip.currentState?.ensureTooltipVisible(),
        radius: 22,
        minWidth: 44,
        selected: on,
        semanticLabel: on
            ? 'Remove ${backend.name} from compare'
            : 'Add ${backend.name} to compare',
        builder: (context, hovered) => Center(
          child: Icon(
            on ? Icons.check_circle : Icons.add_circle_outline,
            size: 22,
            color: on
                ? p.accent
                : can
                ? (hovered ? p.text : p.muted)
                : p.line,
          ),
        ),
      ),
    );
  }
}
