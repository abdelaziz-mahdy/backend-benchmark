import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import '../widgets/common.dart';
import '../widgets/compare_tray.dart';
import '../widgets/implementation.dart';
import '../widgets/motion.dart';
import '../widgets/podium.dart';

export '../utils/colors.dart' show languageLabel;

/// Focus of the leaderboard search field, owned by the shell so "/" can
/// reach it from anywhere on the page.
class SearchFocus extends InheritedWidget {
  final FocusNode node;

  const SearchFocus({super.key, required this.node, required super.child});

  static FocusNode? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SearchFocus>()?.node;

  @override
  bool updateShouldNotify(SearchFocus oldWidget) => node != oldWidget.node;
}

/// Key of the timing sheet, the table of every framework (tests use it to
/// tell a row from the same name on the podium).
const kTimingSheetKey = Key('timing-sheet');

/// Leaderboard: a headline built from the data, the podium of each
/// scenario, then the full timing sheet. A row expands in place with every
/// number, its implementation and the compare actions.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _sheetKey = GlobalKey();

  void _pick(DashboardState state, String scenario) {
    state.setSortScenario(scenario);
    final ctx = _sheetKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: motion(context, 350),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    if (run == null) return const SizedBox.shrink();
    final rows = state.sortedBackends;
    final narrow = MediaQuery.sizeOf(context).width < kNarrow;
    return PageBody(
      children: [
        if (run.isLegacy) _LegacyBanner(state: state),
        _Headline(state: state, run: run),
        if (narrow)
          ScenarioTabs(
            label: 'Rank by',
            scenarios: run.scenarios,
            selected: state.sortScenario,
            onSelected: state.setSortScenario,
          ),
        PodiumStrip(state: state, onPick: (s) => _pick(state, s)),
        Container(
          key: _sheetKey,
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: _SheetHeader(state: state, narrow: narrow),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _Controls(),
              ),
              if (rows.isEmpty)
                EmptyState(
                  icon: Icons.search_off,
                  title: 'No framework matches "${state.query.trim()}"',
                  message:
                      'Try a name, a language or a runtime. Not listed? '
                      'Backends are added with a folder in the repository.',
                  action: OutlinedButton.icon(
                    onPressed: () => state.setQuery(''),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Clear search'),
                  ),
                )
              else
                LayoutBuilder(
                  key: kTimingSheetKey,
                  builder: (context, c) => c.maxWidth < kNarrow
                      ? _Cards(state: state, rows: rows)
                      : _Table(state: state, rows: rows),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: _Footnote(run: run, metric: state.metric),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegacyBanner extends StatelessWidget {
  final DashboardState state;

  const _LegacyBanner({required this.state});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
    decoration: BoxDecoration(
      color: kAmber.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(kRadius),
      border: Border.all(color: kAmber.withValues(alpha: 0.35)),
    ),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.history, size: 16, color: kAmber),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Old v1 method (Locust, 10,000 users, 1 CPU per app, no '
                  'latency limit, 2 scenarios). Kept for history; not '
                  'comparable with current results.',
                  style: body(12.5, color: kTextSecondary),
                ),
              ),
            ],
          ),
        ),
        if (state.index.isNotEmpty && state.entry != state.index.first)
          TextButton.icon(
            onPressed: () => state.selectRun(state.index.first),
            icon: const Icon(Icons.arrow_forward, size: 15),
            label: const Text('Back to latest results'),
            style: TextButton.styleFrom(foregroundColor: kAmber),
          ),
      ],
    ),
  );
}

/// The answer first: who leads where and by how much, built from the
/// podium of every scenario; the question it answers sits above it, and
/// where the numbers come from below.
class _Headline extends StatelessWidget {
  final DashboardState state;
  final RunSummary run;

  const _Headline({required this.state, required this.run});

  @override
  Widget build(BuildContext context) {
    final m = state.metric;
    final label = m.label[0].toLowerCase() + m.label.substring(1);
    final summary = RaceSummary.of(state);
    final question = run.isLegacy
        ? 'v1 results · who averaged the most requests?'
        : !m.isRace
        ? '$label · context, not a race'
        : m == Metrics.sustainable
        ? 'Who holds the most load on ${run.appCores} cores?'
        : 'Who leads on $label?';
    final sources = state.entry?.runs.length ?? 0;
    final facts = [
      run.machine.cpu,
      ?run.date,
      run.isLegacy ? 'v1 method' : 'method ${run.methodology}',
      // v1 runs record no repetitions; never claim a median for them.
      if (run.params['reps'] != null) 'median of ${run.reps} repetitions',
      if (!run.isLegacy) '${run.appCores} pinned cores per app',
      if (sources > 1) 'combined from $sources runs',
    ];
    final s = state.sortScenario;
    final notes = <String>[
      if (!m.isRace)
        'A framework that serves less load can show a lower $label, so '
            'read this as context. Compare puts frameworks side by side at '
            'a load they all held.',
      ?summary.marginLine,
      ...summary.tieNotes,
    ];
    final ranking = s == null
        ? null
        : s == 'db_mixed'
        ? 'The table is ranked by DB mixed (80% reads, 20% inserts), the '
              'closest to a real API.'
        : 'The table is ranked by ${scenarioLabel(s)}: '
              '${_lowerFirst(scenarioHelp(s))}';
    final narrow = MediaQuery.sizeOf(context).width < kNarrow;
    final leader = summary.leader;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const StartLights(),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                question.toUpperCase(),
                style: caps(11.5, color: kSignal, letterSpacing: 1.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leader != null && !narrow) ...[
              Monogram(backend: leader, size: 40),
              const SizedBox(width: 14),
            ],
            Flexible(
              child: Text(
                summary.headline,
                style: display(narrow ? 27 : 40, height: 1.05),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (final n in notes)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              n,
              style: body(narrow ? 13.5 : 15, color: kTextSecondary),
            ),
          ),
        if (ranking != null)
          Text(ranking, style: body(narrow ? 12.5 : 13, color: kTextMuted)),
        const SizedBox(height: 10),
        Text(facts.join('  ·  '), style: mono(11.5, color: kTextMuted)),
      ],
    );
  }
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

class _SheetHeader extends StatelessWidget {
  final DashboardState state;
  final bool narrow;

  const _SheetHeader({required this.state, required this.narrow});

  @override
  Widget build(BuildContext context) {
    final s = state.sortScenario;
    final label = state.metric.label;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FULL TIMING SHEET', style: caps(10.5)),
        const SizedBox(height: 3),
        Text(
          s == null
              ? 'All frameworks'
              : 'Ranked by ${label[0].toLowerCase()}${label.substring(1)} '
                    'in ${scenarioLabel(s)}',
          style: display(20),
        ),
        const SizedBox(height: 3),
        Text(
          narrow
              ? 'Tap a framework for every number, or the arrow for its '
                    'charts. Re-rank with the scenario tabs above.'
              : 'Tap a framework for every number. Tap a scenario column to '
                    're-rank.',
          style: body(12.5, color: kTextMuted),
        ),
      ],
    );
  }
}

/// Metric gauge tabs, the search field, the direction of "better" and the
/// marker legend. Phones also get a "Rank by" scenario control.
class _Controls extends StatefulWidget {
  const _Controls();

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  late final TextEditingController _controller;
  late final DashboardState _state;
  FocusNode? _own;

  @override
  void initState() {
    super.initState();
    _state = context.read<DashboardState>();
    _controller = TextEditingController(text: _state.query);
    _state.addListener(_sync);
  }

  /// Keeps the field in step when the query is changed elsewhere (Clear,
  /// a run switch); done outside build so the hint reappears on empty.
  void _sync() {
    if (_controller.text != _state.query) {
      _controller.value = TextEditingValue(
        text: _state.query,
        selection: TextSelection.collapsed(offset: _state.query.length),
      );
    }
  }

  @override
  void dispose() {
    _state.removeListener(_sync);
    _controller.dispose();
    _own?.dispose();
    super.dispose();
  }

  FocusNode get _focus =>
      SearchFocus.maybeOf(context) ?? (_own ??= FocusNode());

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final focus = _focus;
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < kNarrow;
        final search = _SearchField(
          controller: _controller,
          focus: focus,
          state: state,
          narrow: narrow,
        );
        final hint = _BetterHint(metric: state.metric);
        // Only the markers this run has; the footnote lists all of them.
        final present = {
          for (final b in state.run!.backends)
            for (final r in b.scenarios.values) ...Marker.of(r),
        };
        final legend = MarkerLegend(
          compact: true,
          markers: Marker.values.where(present.contains),
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MetricMenu(state: state),
              const SizedBox(height: 10),
              search,
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [hint, legend],
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MetricTabs(state: state),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [search, hint, legend],
            ),
          ],
        );
      },
    );
  }
}

class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final DashboardState state;
  final bool narrow;

  const _SearchField({
    required this.controller,
    required this.focus,
    required this.state,
    required this.narrow,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    if (old.focus != widget.focus) {
      old.focus.removeListener(_onFocus);
      widget.focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focus.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final focused = widget.focus.hasFocus;
    final field = TextField(
      controller: widget.controller,
      focusNode: widget.focus,
      onChanged: state.setQuery,
      onSubmitted: state.expandFirstMatch,
      style: body(13.5, color: kTextPrimary),
      cursorColor: kSignal,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 11,
        ),
        hintText: 'Search name, language, runtime',
        hintStyle: body(13, color: kTextDim),
        prefixIcon: const Icon(Icons.search, size: 18, color: kTextMuted),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        suffixIcon: state.query.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, color: kTextMuted),
                onPressed: () => state.setQuery(''),
              )
            : (focused || widget.narrow)
            ? null
            : const _KeyCap('/'),
        suffixIconConstraints: const BoxConstraints(minWidth: 32),
        filled: true,
        fillColor: kBackground,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: kBorderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: kSignal, width: 1.5),
        ),
      ),
    );
    if (widget.narrow) return field;
    return AnimatedContainer(
      duration: motion(context, 200),
      curve: Curves.easeOutCubic,
      width: focused || state.query.isNotEmpty ? 380 : 320,
      child: field,
    );
  }
}

class _KeyCap extends StatelessWidget {
  final String text;

  const _KeyCap(this.text);

  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Press / to search',
    child: Center(
      widthFactor: 1,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: kBorderStrong),
        ),
        child: Text(text, style: mono(11, color: kTextMuted)),
      ),
    ),
  );
}

IconData metricIcon(Metric m) => switch (m.id) {
  'sustainable_rps' || 'avg_rps' => Icons.bolt,
  'peak_rps' => Icons.north_east,
  'error_rate' => Icons.error_outline,
  'app_cpu' => Icons.memory,
  'db_cpu' => Icons.storage,
  'app_mem_mb' => Icons.sd_storage_outlined,
  'rps_per_core' => Icons.developer_board,
  'rps_per_100mb' => Icons.inventory_2_outlined,
  _ => Icons.timer_outlined,
};

/// Phones: "Showing" as one menu button, so every metric is reachable
/// without a sideways scroll.
class _MetricMenu extends StatelessWidget {
  final DashboardState state;

  const _MetricMenu({required this.state});

  static String _label(Metric m) =>
      m == Metrics.sustainable ? 'Sustainable load' : m.label;

  @override
  Widget build(BuildContext context) {
    final current = state.metric;
    return PopupMenuButton<Metric>(
      tooltip: 'Choose the number shown',
      initialValue: current,
      color: kCardBgRaised,
      onSelected: state.setMetric,
      itemBuilder: (context) => [
        for (final m in state.availableMetrics)
          PopupMenuItem(
            value: m,
            child: Row(
              children: [
                Icon(
                  metricIcon(m),
                  size: 16,
                  color: m == current ? kSignal : kTextSecondary,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    _label(m),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(
                      13.5,
                      color: m == current ? kSignal : kTextPrimary,
                      weight: m == current ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: kSignal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kSignal.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Text('SHOWING', style: caps(10.5, color: kTextSecondary)),
            const SizedBox(width: 8),
            Icon(metricIcon(current), size: 15, color: kSignal),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                _label(current),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(13, color: kSignal, weight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: kSignal),
          ],
        ),
      ),
    );
  }
}

/// "Showing": the number in every cell, as a row of gauge tabs.
class _MetricTabs extends StatelessWidget {
  final DashboardState state;

  const _MetricTabs({required this.state});

  @override
  Widget build(BuildContext context) {
    final metrics = state.availableMetrics;
    return Row(
      children: [
        Text('SHOWING', style: caps(10.5)),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final m in metrics)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _GaugeTab(
                      metric: m,
                      selected: m == state.metric,
                      onTap: () => state.setMetric(m),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GaugeTab extends StatelessWidget {
  final Metric metric;
  final bool selected;
  final VoidCallback onTap;

  const _GaugeTab({
    required this.metric,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? kSignal : kTextSecondary;
    final label = metric == Metrics.sustainable
        ? 'Sustainable load'
        : metric.short;
    return Tooltip(
      message: '${metric.labelWithUnit}: ${metric.help}',
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: motion(context, 180),
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: selected ? kSignal.withValues(alpha: 0.1) : kBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? kSignal.withValues(alpha: 0.6) : kBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(metricIcon(metric), size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: body(
                    12.5,
                    color: color,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Which way is better for the shown metric; bars are always "longer is
/// better", so for lower-is-better metrics they show the share of the best.
class _BetterHint extends StatelessWidget {
  final Metric metric;

  const _BetterHint({required this.metric});

  @override
  Widget build(BuildContext context) {
    final up = metric.higherIsBetter;
    return Tooltip(
      message: up
          ? 'Bars show each value against the best in its column.'
          : 'Bars show the best value divided by each value, so a longer '
                'bar is still better.',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: kSignal,
          ),
          const SizedBox(width: 4),
          Text(
            up ? 'HIGHER IS BETTER' : 'LOWER IS BETTER',
            style: caps(10.5, color: kTextSecondary),
          ),
        ],
      ),
    );
  }
}

/// Competition ranks for rows already sorted by the sort column: tied
/// values share a position (1, 1, 1, 4, …). Ranks count every framework,
/// so a search never renumbers them.
List<int> _positions(DashboardState state, List<BackendResult> sorted) {
  final all = state.allRanked;
  final byKey = <String, int>{};
  for (var i = 0; i < all.length; i++) {
    final v = state.valueOf(all[i], state.metric, state.sortScenario);
    final prev = i == 0
        ? null
        : state.valueOf(all[i - 1], state.metric, state.sortScenario);
    byKey[all[i].key] = i > 0 && v != null && prev == v
        ? byKey[all[i - 1].key]!
        : i + 1;
  }
  return [for (final b in sorted) byKey[b.key] ?? 0];
}

/// Best value of the shown metric per scenario, over every framework of the
/// run (search does not rescale), and how many share it.
class _Columns {
  final Map<String, double> best = {};
  final Map<String, int> leaders = {};
  final Metric metric;

  _Columns(DashboardState state) : metric = state.metric {
    for (final s in state.run!.scenarios) {
      double? b;
      for (final x in state.allRanked) {
        final v = state.valueOf(x, metric, s);
        if (v == null) continue;
        if (b == null || (metric.higherIsBetter ? v > b : v < b)) {
          b = v;
        }
      }
      if (b != null) {
        best[s] = b;
        leaders[s] = state.allRanked
            .where((x) => state.valueOf(x, metric, s) == b)
            .length;
      }
    }
  }

  /// Bar share, longer is better.
  double share(String s, double? v) => barShare(metric, v, best[s]);
}

/// Desktop timing sheet: the ranked scenario is the race lane (thick bar,
/// gap to the leader, finish line); the other scenarios are heat cells, so
/// a framework's pattern across scenarios reads at a glance.
class _Table extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> rows;

  const _Table({required this.state, required this.rows});

  @override
  Widget build(BuildContext context) {
    final scenarios = state.run!.scenarios;
    final positions = _positions(state, rows);
    final cols = _Columns(state);
    final sortS = state.sortScenario;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _layout(
          header: true,
          sortS: sortS,
          scenarios: scenarios,
          rank: Text('POS', style: caps(10.5)),
          name: Text('FRAMEWORK', style: caps(10.5)),
          cells: [
            for (final s in scenarios) _ScenarioHeader(state: state, s: s),
          ],
          action: SizedBox(
            width: 84,
            child: Text(
              'COMPARE',
              textAlign: TextAlign.right,
              style: caps(10.5),
            ),
          ),
        ),
        RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                FlipOnMove(
                  key: ValueKey('row-${rows[i].key}'),
                  child: _RowShell(
                    backend: rows[i],
                    leader: positions[i] == 1 && state.metric.isRace,
                    expanded: state.expandedKey == rows[i].key,
                    onTap: () => state.toggleExpanded(rows[i].key),
                    child: _layout(
                      sortS: sortS,
                      scenarios: scenarios,
                      rank: _Position(positions[i], race: state.metric.isRace),
                      name: _NameCell(backend: rows[i]),
                      cells: [
                        for (final s in scenarios)
                          s == sortS
                              ? _LaneCell(
                                  state: state,
                                  backend: rows[i],
                                  scenario: s,
                                  cols: cols,
                                  stagger: i / (rows.length + 2) * 0.5,
                                )
                              : _HeatCell(
                                  state: state,
                                  backend: rows[i],
                                  scenario: s,
                                  cols: cols,
                                ),
                      ],
                      action: SizedBox(
                        width: 84,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            CompareToggle(state: state, backend: rows[i]),
                            IconButton(
                              tooltip: 'Open ${rows[i].name} details',
                              onPressed: () => state.openDetails(rows[i].key),
                              icon: const Icon(
                                Icons.chevron_right,
                                color: kTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.expandedKey == rows[i].key)
                  _ExpandedPanel(
                    key: ValueKey('panel-${rows[i].key}'),
                    state: state,
                    backend: rows[i],
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _layout({
    required Widget rank,
    required Widget name,
    required List<Widget> cells,
    required Widget action,
    required String? sortS,
    required List<String> scenarios,
    bool header = false,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, header ? 6 : 8, 12, header ? 8 : 8),
      decoration: header
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: kBorder)),
            )
          : null,
      child: Row(
        children: [
          SizedBox(width: 44, child: rank),
          Expanded(flex: 24, child: name),
          for (var i = 0; i < cells.length; i++) ...[
            const SizedBox(width: 10),
            Expanded(flex: scenarios[i] == sortS ? 22 : 12, child: cells[i]),
          ],
          const SizedBox(width: 10),
          action,
        ],
      ),
    );
  }
}

class _ScenarioHeader extends StatelessWidget {
  final DashboardState state;
  final String s;

  const _ScenarioHeader({required this.state, required this.s});

  @override
  Widget build(BuildContext context) {
    final active = s == state.sortScenario;
    return Tooltip(
      message: '${scenarioHelp(s)}\nTap to rank by this scenario.',
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        selected: active,
        label: 'Rank by ${scenarioLabel(s)}',
        excludeSemantics: true,
        child: InkWell(
          onTap: () => state.setSortScenario(s),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? kSignal : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    active
                        ? 'RANKED BY ${scenarioLabel(s).toUpperCase()}'
                        : scenarioLabel(s).toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: caps(11, color: active ? kSignal : kTextSecondary),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  active
                      ? (state.metric.higherIsBetter
                            ? Icons.arrow_downward
                            : Icons.arrow_upward)
                      : Icons.unfold_more,
                  size: 13,
                  color: active ? kSignal : kTextDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Position extends StatelessWidget {
  final int position;

  /// Lime for P1 only when the metric is a race (see [Metric.isRace]).
  final bool race;

  const _Position(this.position, {this.race = true});

  @override
  Widget build(BuildContext context) => Text(
    position == 0 ? '—' : 'P$position',
    style: mono(
      14,
      weight: FontWeight.w700,
      color: position == 1 && race
          ? kSignal
          : position <= 3
          ? kTextPrimary
          : kTextMuted,
    ),
  );
}

/// Focusable, tappable lane: Enter or Space expands it, like a click. The
/// leader's lane carries a chequered edge.
class _RowShell extends StatefulWidget {
  final BackendResult backend;
  final bool leader;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  const _RowShell({
    required this.backend,
    required this.leader,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  @override
  State<_RowShell> createState() => _RowShellState();
}

class _RowShellState extends State<_RowShell> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final color = BackendColors.of(widget.backend.key);
    return Semantics(
      button: true,
      expanded: widget.expanded,
      hint: widget.expanded ? 'Collapse' : 'Show every number',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hover = h),
          onFocusChange: (f) => setState(() => _focus = f),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          splashColor: kSignal.withValues(alpha: 0.06),
          child: AnimatedContainer(
            duration: motion(context, 160),
            decoration: BoxDecoration(
              color: widget.expanded
                  ? kCardBgRaised
                  : (_hover ? kCardBgRaised.withValues(alpha: 0.7) : null),
              border: Border(
                top: const BorderSide(color: kGridLine),
                left: BorderSide(
                  color: widget.expanded || _hover ? color : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            foregroundDecoration: _focus
                ? BoxDecoration(
                    border: Border.all(color: kSignal, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: widget.leader
                ? Stack(
                    children: [
                      widget.child,
                      const Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: ChequerBand(thickness: 6),
                      ),
                    ],
                  )
                : widget.child,
          ),
        ),
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  final BackendResult backend;
  final double monogram;

  const _NameCell({required this.backend, this.monogram = 28});

  @override
  Widget build(BuildContext context) {
    final b = backend;
    return Row(
      children: [
        Monogram(backend: b, size: monogram),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                b.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(14.5, color: kTextPrimary, weight: FontWeight.w600),
              ),
              Text(
                [
                  languageLabel(b.language),
                  ...b.subtitle.split(' · '),
                ].where((s) => s.isNotEmpty).join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(11.5, color: kTextMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "LEADER" / "−25%" / "LOWEST" for a value in the ranked column.
(String, bool) _gapText(_Columns cols, String scenario, double? v) {
  final best = cols.best[scenario];
  final m = cols.metric;
  if (v == null || best == null) return ('', false);
  if (v == best) {
    final tied = (cols.leaders[scenario] ?? 1) > 1;
    if (!m.isRace) return (tied ? 'TIED LOWEST' : 'LOWEST', true);
    return (tied ? 'TIED LEAD' : 'LEADER', true);
  }
  return (gapToLeader(m, v, best), false);
}

/// The race lane of a row: value and gap on one line, a thick bar under
/// them that ends at a lime finish line. "—" when not measured; amber
/// icons mark capped, noisy or restarted results.
class _LaneCell extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final String scenario;
  final _Columns cols;
  final double stagger;

  const _LaneCell({
    required this.state,
    required this.backend,
    required this.scenario,
    required this.cols,
    required this.stagger,
  });

  @override
  Widget build(BuildContext context) {
    final r = backend.scenarios[scenario];
    final m = state.metric;
    final v = r == null ? null : m.value(r);
    final (gap, top) = _gapText(cols, scenario, v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              formatMetricShort(m, v),
              style: mono(
                15.5,
                weight: FontWeight.w700,
                color: v == null ? kTextDim : kTextPrimary,
              ),
            ),
            MarkerIcons(r, size: 13),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                gap,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: top
                    ? caps(10.5, color: m.isRace ? kSignal : kTextSecondary)
                    : mono(11.5, color: kTextMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LaneBar(
          fraction: cols.share(scenario, v),
          color: BackendColors.of(backend.key),
          height: 7,
          stagger: stagger,
          finish: m.isRace,
        ),
      ],
    );
  }
}

/// A scenario the table is not ranked by: the value on a tint whose
/// strength is its share of the best (lime for race metrics, neutral for
/// context ones). Tapping it ranks the table by that scenario.
class _HeatCell extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final String scenario;
  final _Columns cols;
  final bool showLabel;

  const _HeatCell({
    required this.state,
    required this.backend,
    required this.scenario,
    required this.cols,
    this.showLabel = false,
  });

  /// Tint for a share of the best, 0..1. Neutral on purpose: lime is kept
  /// for the leader, so the best cell gets a lime border instead. The top
  /// race tint (21%) still keeps secondary text and amber markers above
  /// 5:1.
  static Color tint(Metric m, double share) => m.isRace
      ? kTextPrimary.withValues(alpha: 0.03 + 0.18 * share)
      : kTextPrimary.withValues(alpha: 0.03 + 0.12 * share);

  @override
  Widget build(BuildContext context) {
    final r = backend.scenarios[scenario];
    final m = state.metric;
    final v = r == null ? null : m.value(r);
    final share = cols.share(scenario, v);
    final best = v != null && v == cols.best[scenario];
    return Semantics(
      button: true,
      label:
          '${scenarioLabel(scenario)}: ${formatMetric(m, v)}. '
          'Rank by ${scenarioLabel(scenario)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => state.setSortScenario(scenario),
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: motion(context, 300),
          padding: EdgeInsets.fromLTRB(8, showLabel ? 5 : 0, 6, 0),
          height: showLabel ? 46 : 34,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: v == null ? Colors.transparent : tint(m, share),
            borderRadius: BorderRadius.circular(6),
            border: showLabel && scenario == state.sortScenario
                ? Border.all(color: kSignal, width: 1.5)
                : best && m.isRace
                ? Border.all(color: kSignal.withValues(alpha: 0.6))
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showLabel)
                Text(
                  scenarioLabel(scenario).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: caps(10, color: kTextSecondary, letterSpacing: 0.8),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatMetricShort(m, v),
                      style: mono(
                        13,
                        weight: best ? FontWeight.w700 : FontWeight.w500,
                        color: v == null ? kTextDim : kTextPrimary,
                      ),
                    ),
                    MarkerIcons(r, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phone layout: one compact lane per framework (position, name, the
/// ranked value with its gap, a full-width bar, compare and details). The
/// other scenarios are in the expanded panel.
class _Cards extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> rows;

  const _Cards({required this.state, required this.rows});

  @override
  Widget build(BuildContext context) {
    final sortS = state.sortScenario;
    final positions = _positions(state, rows);
    final cols = _Columns(state);
    final m = state.metric;
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            FlipOnMove(
              key: ValueKey('row-${rows[i].key}'),
              child: _RowShell(
                backend: rows[i],
                leader: positions[i] == 1 && m.isRace,
                expanded: state.expandedKey == rows[i].key,
                onTap: () => state.toggleExpanded(rows[i].key),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 0, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: _Position(positions[i], race: m.isRace),
                          ),
                          Expanded(
                            child: _NameCell(backend: rows[i], monogram: 26),
                          ),
                          const SizedBox(width: 6),
                          if (sortS != null)
                            _CompactValue(
                              backend: rows[i],
                              scenario: sortS,
                              cols: cols,
                            ),
                          const SizedBox(width: 6),
                          CompareToggle(state: state, backend: rows[i]),
                          IconButton(
                            tooltip: 'Open ${rows[i].name} details',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => state.openDetails(rows[i].key),
                            icon: const Icon(
                              Icons.chevron_right,
                              color: kTextMuted,
                            ),
                          ),
                        ],
                      ),
                      if (sortS != null) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 36, right: 14),
                          child: LaneBar(
                            fraction: cols.share(
                              sortS,
                              state.valueOf(rows[i], m, sortS),
                            ),
                            color: BackendColors.of(rows[i].key),
                            height: 6,
                            stagger: i / (rows.length + 2) * 0.5,
                            finish: m.isRace,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (state.expandedKey == rows[i].key)
              _ExpandedPanel(
                key: ValueKey('panel-${rows[i].key}'),
                state: state,
                backend: rows[i],
              ),
          ],
        ],
      ),
    );
  }
}

/// Phone: the ranked value with its markers, and the gap under it.
class _CompactValue extends StatelessWidget {
  final BackendResult backend;
  final String scenario;
  final _Columns cols;

  const _CompactValue({
    required this.backend,
    required this.scenario,
    required this.cols,
  });

  @override
  Widget build(BuildContext context) {
    final r = backend.scenarios[scenario];
    final m = cols.metric;
    final v = r == null ? null : m.value(r);
    final (gap, top) = _gapText(cols, scenario, v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatMetricShort(m, v),
              style: mono(
                15,
                weight: FontWeight.w700,
                color: v == null ? kTextDim : kTextPrimary,
              ),
            ),
            MarkerIcons(r, size: 12),
          ],
        ),
        if (gap.isNotEmpty)
          Text(
            gap,
            style: top
                ? caps(10, color: m.isRace ? kSignal : kTextSecondary)
                : mono(10.5, color: kTextMuted),
          ),
      ],
    );
  }
}

/// What opens under a tapped row: actions, every metric for every scenario,
/// rank, markers in words, and how the backend is implemented.
class _ExpandedPanel extends StatefulWidget {
  final DashboardState state;
  final BackendResult backend;

  const _ExpandedPanel({super.key, required this.state, required this.backend});

  @override
  State<_ExpandedPanel> createState() => _ExpandedPanelState();
}

class _ExpandedPanelState extends State<_ExpandedPanel> {
  @override
  void initState() {
    super.initState();
    // A row opened low on the screen (or with the keyboard) scrolls its
    // panel into view; one already in view stays put.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final scrollable = Scrollable.maybeOf(context);
      final viewport = scrollable?.context.findRenderObject() as RenderBox?;
      if (box == null || viewport == null || !box.attached) return;
      final top = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
      if (top > viewport.size.height * 0.7 || top < 0) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.15,
          duration: motion(context, 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  DashboardState get state => widget.state;

  void _compareWithLeaders(BuildContext context, String key) {
    if (state.compareWithLeaders(key)) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          'The comparison is full (${DashboardState.maxCompare} of '
          '${DashboardState.maxCompare}): remove one to add the leaders.',
          style: body(13, color: kTextPrimary),
        ),
        backgroundColor: kCardBgRaised,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.backend;
    final scenarios = state.run!.scenarios;
    final present = scenarios.where(b.scenarios.containsKey).toList();
    final results = b.scenarios.values;
    final metrics = Metrics.available(results, Metrics.table);
    final others = state.allRanked.length - 1;
    final sortS = state.sortScenario;
    final rank = sortS == null ? null : state.rankOf(b, state.metric, sortS);
    final first = rank != null && rank.position == 1 && rank.tied == 1;
    final narrow = MediaQuery.sizeOf(context).width < kNarrow;
    final cols = _Columns(state);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: kCardBgRaised,
        border: Border(
          left: BorderSide(color: BackendColors.of(b.key), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: others >= 1
                    ? () => _compareWithLeaders(context, b.key)
                    : null,
                icon: const Icon(Icons.compare_arrows, size: 16),
                label: Text(
                  first
                      ? 'Compare with the runners-up'
                      : sortS == null
                      ? 'Compare with the leaders'
                      : 'Compare with the ${scenarioLabel(sortS)} leaders',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: kSignal,
                  foregroundColor: kSignalInk,
                  visualDensity: VisualDensity.compact,
                  textStyle: labelStyle(context, 13, weight: FontWeight.w700),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => state.openDetails(b.key),
                icon: const Icon(Icons.show_chart, size: 16),
                label: const Text('Full details and charts'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextPrimary,
                  side: const BorderSide(color: kBorderStrong),
                  visualDensity: VisualDensity.compact,
                  textStyle: labelStyle(context, 13),
                ),
              ),
              if (b.sourceUrl != null)
                SourceLink(url: b.sourceUrl!, label: 'Source on GitHub'),
            ],
          ),
          if (narrow && present.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('EVERY SCENARIO · TAP TO RANK BY IT', style: caps(10.5)),
            const SizedBox(height: 6),
            Row(
              children: [
                for (var i = 0; i < scenarios.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _HeatCell(
                      state: state,
                      backend: b,
                      scenario: scenarios[i],
                      cols: cols,
                      showLabel: true,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (present.isEmpty)
            Text(
              'Not measured in this run.',
              style: body(13, color: kTextMuted),
            )
          else
            LayoutBuilder(
              builder: (context, c) => c.maxWidth < 640
                  ? _NarrowGrid(
                      state: state,
                      backend: b,
                      scenarios: scenarios,
                      metrics: metrics,
                    )
                  : _Grid(
                      state: state,
                      backend: b,
                      scenarios: scenarios,
                      metrics: metrics,
                    ),
            ),
          ..._notes(b, present),
          const SizedBox(height: 14),
          _implementation(b),
        ],
      ),
    );
  }

  /// Markers written out, one line per scenario they apply to.
  List<Widget> _notes(BackendResult b, List<String> present) {
    final lines = <(IconData?, String)>[];
    final bound = present.where((s) => b.scenarios[s]!.loadgenBound).toList();
    if (bound.isNotEmpty) {
      lines.add((
        Marker.capped.icon,
        '${bound.map(scenarioLabel).join(', ')}: the load generator was the '
            'limit here; the real number may be higher.',
      ));
    }
    for (final s in present) {
      final r = b.scenarios[s]!;
      if (r.unstable) {
        lines.add((
          Marker.noisy.icon,
          '${scenarioLabel(s)}: repetitions differed by '
              '${(r.spread * 100).toStringAsFixed(0)}%; treat small '
              'differences with care.',
        ));
      }
    }
    for (final s in present) {
      final n = b.scenarios[s]!.restarts;
      if (n > 0) {
        lines.add((
          Marker.restarted.icon,
          '${scenarioLabel(s)}: under overload the app stopped responding '
              'and had to be restarted ${n == 1 ? 'once' : '$n times'}; it '
              'did not recover by itself.',
        ));
      }
    }
    if (b.notes != null) lines.add((null, 'Note: ${b.notes}'));
    if (lines.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      for (final (icon, text) in lines)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: icon == null
                    ? const Icon(Icons.notes, size: 14, color: kTextMuted)
                    : Icon(icon, size: 14, color: kAmber),
              ),
              Expanded(child: Text(text, style: body(12.5))),
            ],
          ),
        ),
    ];
  }

  Widget _implementation(BackendResult b) {
    final impl = b.implementation;
    final facts = <(String, String)>[
      ...?impl?.facts,
      ('API', b.apiLabel),
      ('Database', b.storageLabel),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HOW IT IS IMPLEMENTED', style: caps(10.5)),
        const SizedBox(height: 8),
        if (impl == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'No implementation details recorded; see the source folder.',
              style: body(12.5, color: kTextMuted),
            ),
          ),
        FactList(facts: [for (final (l, v) in facts) (l, factText(v))]),
        if (b.implementationFrom == 'manifest')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Details come from the current source, not from this run.',
              style: body(11.5, color: kTextDim),
            ),
          ),
      ],
    );
  }
}

String _rankText(DashboardState state, BackendResult b, Metric m, String s) {
  final rank = state.rankOf(b, m, s);
  return rank == null ? '—' : rank.label;
}

String _shareText(DashboardState state, BackendResult b, Metric m, String s) {
  final rank = state.rankOf(b, m, s);
  if (rank == null) return '—';
  if (rank.position == 1) return rank.tied > 1 ? 'tied best' : 'best';
  final share = m.higherIsBetter
      ? rank.shareOfLeader
      : (rank.value != null && rank.value! > 0 && rank.leader != null
            ? rank.leader! / rank.value!
            : null);
  return share == null ? '—' : '${(share * 100).round()}%';
}

String _cellText(BackendResult b, Metric m, String s) {
  final r = b.scenarios[s];
  if (r == null) return '—';
  return formatMetricShort(m, m.value(r));
}

/// Metric rows × scenario columns for one framework, with a rank row for
/// the number the table shows.
class _Grid extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final List<String> scenarios;
  final List<Metric> metrics;

  const _Grid({
    required this.state,
    required this.backend,
    required this.scenarios,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final shown = state.metric;
    final rankMetric = metrics.contains(shown) ? shown : metrics.first;
    final label = body(12.5, color: kTextMuted);
    final value = mono(12.5, color: kTextSecondary);
    final strong = mono(12.5, color: kTextPrimary, weight: FontWeight.w700);
    return Table(
      columnWidths: {
        0: const FixedColumnWidth(190),
        for (var i = 0; i < scenarios.length; i++)
          i + 1: const FixedColumnWidth(118),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          children: [
            const SizedBox(height: 28),
            for (final s in scenarios)
              Text(
                scenarioLabel(s),
                textAlign: TextAlign.right,
                style: body(
                  12,
                  color: s == state.sortScenario ? kSignal : kTextMuted,
                  weight: FontWeight.w600,
                ),
              ),
          ],
        ),
        for (final m in metrics)
          TableRow(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Tooltip(
                  message: m.help,
                  waitDuration: const Duration(milliseconds: 400),
                  child: Text(
                    m.labelWithUnit,
                    style: m == rankMetric
                        ? label.copyWith(
                            color: kTextPrimary,
                            fontWeight: FontWeight.w600,
                          )
                        : label,
                  ),
                ),
              ),
              for (final s in scenarios)
                Text(
                  _cellText(backend, m, s),
                  textAlign: TextAlign.right,
                  style: m == rankMetric ? strong : value,
                ),
            ],
          ),
        TableRow(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kBorder)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'Rank by ${rankMetric.short.toLowerCase()}',
                style: label,
              ),
            ),
            for (final s in scenarios)
              Text(
                _rankText(state, backend, rankMetric, s),
                textAlign: TextAlign.right,
                style: strong,
              ),
          ],
        ),
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text('Share of the best', style: label),
            ),
            for (final s in scenarios)
              Text(
                _shareText(state, backend, rankMetric, s),
                textAlign: TextAlign.right,
                style: value,
              ),
          ],
        ),
      ],
    );
  }
}

/// Phone version of the grid: one scenario at a time (tabs), as a
/// label/value list that fits 360 px.
class _NarrowGrid extends StatefulWidget {
  final DashboardState state;
  final BackendResult backend;
  final List<String> scenarios;
  final List<Metric> metrics;

  const _NarrowGrid({
    required this.state,
    required this.backend,
    required this.scenarios,
    required this.metrics,
  });

  @override
  State<_NarrowGrid> createState() => _NarrowGridState();
}

class _NarrowGridState extends State<_NarrowGrid> {
  String? _scenario;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final s = widget.scenarios.contains(_scenario)
        ? _scenario!
        : (state.sortScenario ?? widget.scenarios.first);
    final shown = state.metric;
    final rankMetric = widget.metrics.contains(shown)
        ? shown
        : widget.metrics.first;
    Widget line(String label, String value, {bool strong = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: body(
                12.5,
                color: strong ? kTextPrimary : kTextMuted,
                weight: strong ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: mono(
              13,
              color: strong ? kTextPrimary : kTextSecondary,
              weight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScenarioTabs(
          scenarios: widget.scenarios,
          selected: s,
          onSelected: (x) => setState(() => _scenario = x),
          empty: {
            for (final x in widget.scenarios)
              if (!widget.backend.scenarios.containsKey(x)) x,
          },
        ),
        const SizedBox(height: 8),
        for (final m in widget.metrics)
          line(
            m.labelWithUnit,
            _cellText(widget.backend, m, s),
            strong: m == rankMetric,
          ),
        const Divider(color: kBorder, height: 12),
        line(
          'Rank by ${rankMetric.short.toLowerCase()}',
          _rankText(state, widget.backend, rankMetric, s),
          strong: true,
        ),
        line(
          'Share of the best',
          _shareText(state, widget.backend, rankMetric, s),
        ),
      ],
    );
  }
}

/// What the numbers are, under the table. No tooltips needed.
class _Footnote extends StatelessWidget {
  final RunSummary run;
  final Metric metric;

  const _Footnote({required this.run, required this.metric});

  @override
  Widget build(BuildContext context) {
    final reps = run.reps;
    final what = run.isLegacy
        ? '${metric.label}: ${metric.help}'
        : metric == Metrics.sustainable
        ? 'Sustainable load: the highest request rate each framework held '
              'with p99 < 100 ms and < 1% errors, on ${run.appCores} pinned '
              'cores, median of $reps repetitions.'
        : '${metric.label}: ${metric.help} Measured at each framework\'s '
              'own sustainable load, on ${run.appCores} pinned cores, median '
              'of $reps repetitions.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(what, style: body(12, color: kTextMuted, height: 1.45)),
        const SizedBox(height: 8),
        const MarkerLegend(),
      ],
    );
  }
}
