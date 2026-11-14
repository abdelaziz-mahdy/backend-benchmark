import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/compare_tray.dart';
import '../widgets/implementation.dart';
import '../widgets/motion.dart';
import '../widgets/podium.dart' show joinAnd;
import '../widgets/race_replay.dart';
import 'framework_screen.dart' show CopyLinkButton;

/// Two to four frameworks side by side: the headline in every scenario,
/// then a grouped metric table, charts and implementation facts for the
/// selected scenario.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

enum _OverTime { cpu, memory, dbCpu, rps }

class _CompareScreenState extends State<CompareScreen> {
  _OverTime _overTime = _OverTime.cpu;
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    if (run == null) return const SizedBox.shrink();
    final picked = [for (final k in state.compareKeys) ?run.backend(k)];
    final selected = state.compared(state.scenario);
    return PageBody(
      children: [
        PageTitle(
          eyebrow: 'Head to head',
          title: picked.length < 2
              ? 'Compare'
              : picked.map((b) => b.name).join(' vs '),
          onBack: state.goHome,
          trailing: picked.length < 2 ? null : const CopyLinkButton(),
          inlineTrailing: true,
        ),
        if (picked.length >= 2) _Verdict(state: state, picked: picked),
        _Picked(state: state, picked: picked),
        if (picked.length < 2)
          const EmptyState(
            icon: Icons.compare_arrows,
            title: 'Pick at least two frameworks to compare',
            message:
                'On the leaderboard, tap + on a row, or open a row and '
                'tap "Compare with the … leaders".',
          )
        else ...[
          _AllScenarios(state: state, picked: picked),
          if (picked.any(
            (b) => b.scenarios.values.any((r) => r.steps.isNotEmpty),
          ))
            _Replay(state: state, picked: picked),
          ScenarioTabs(
            label: 'Scenario',
            scenarios: run.scenarios,
            selected: state.scenario,
            onSelected: state.setScenario,
          ),
          if (selected.length < 2)
            EmptyState(
              icon: Icons.info_outline,
              title:
                  'Fewer than two of them were measured in '
                  '${scenarioLabel(state.scenario ?? '')}',
              message: 'Pick another scenario above.',
            )
          else ...[
            _Table(
              state: state,
              selected: selected,
              more: _more,
              onMore: () => setState(() => _more = !_more),
            ),
            if (selected.any((b) => state.resultOf(b)!.steps.isNotEmpty))
              _steps(state, selected),
            _overTimeCard(state, selected),
          ],
        ],
      ],
    );
  }

  Widget _steps(DashboardState state, List<BackendResult> selected) {
    final series = [
      for (final b in selected)
        if (state.resultOf(b)!.steps.isNotEmpty)
          StepSeries(b, state.resultOf(b)!.steps),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final a = SectionCard(
          eyebrow: 'Throughput',
          title: 'Served vs requested, per load step',
          subtitle:
              'Where each line leaves the dashed diagonal, it stops keeping up.',
          child: Column(
            children: [
              StepLoadChart(series: series, mode: StepChartMode.throughput),
              const SizedBox(height: 8),
              ChartLegend(backends: selected),
            ],
          ),
        );
        final b = SectionCard(
          eyebrow: 'Latency',
          title: 'p99 per load step',
          subtitle:
              'Red zone = above the 100 ms SLO; hollow red points failed.',
          child: Column(
            children: [
              StepLoadChart(series: series, mode: StepChartMode.p99),
              const SizedBox(height: 8),
              ChartLegend(backends: selected),
            ],
          ),
        );
        if (c.maxWidth < 900) {
          return Column(children: [a, const SizedBox(height: 16), b]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 16),
            Expanded(child: b),
          ],
        );
      },
    );
  }

  Widget _overTimeCard(DashboardState state, List<BackendResult> selected) {
    final series = [
      for (final b in selected)
        if (!state.resultOf(b)!.timeseries.isEmpty)
          (b, state.resultOf(b)!.timeseries),
    ];
    if (series.isEmpty) return const SizedBox.shrink();
    final available = {
      _OverTime.cpu: series.any((s) => s.$2.series.containsKey('app_cpu')),
      _OverTime.memory: series.any(
        (s) => s.$2.series.containsKey('app_mem_mb'),
      ),
      _OverTime.dbCpu: series.any((s) => s.$2.series.containsKey('db_cpu')),
      _OverTime.rps: series.any((s) => s.$2.series.containsKey('rps')),
    };
    final mode = available[_overTime]! ? _overTime : _OverTime.cpu;
    final field = switch (mode) {
      _OverTime.cpu => 'app_cpu',
      _OverTime.memory => 'app_mem_mb',
      _OverTime.dbCpu => 'db_cpu',
      _OverTime.rps => 'rps',
    };
    final chart = switch (mode) {
      _OverTime.memory => TimeSeriesChart(
        series: series,
        field: field,
        formatFor: memoryAxisFormatter,
      ),
      _OverTime.rps => TimeSeriesChart(
        series: series,
        field: field,
        format: formatNumber,
      ),
      _ => TimeSeriesChart(
        series: series,
        field: field,
        format: (v) => '${v.toStringAsFixed(0)}%',
      ),
    };
    return SectionCard(
      eyebrow: 'Resources',
      title: 'Over time',
      subtitle:
          'Whole run, warmup included. Faster frameworks run more steps, so their lines are longer.',
      trailing: SegmentedButton<_OverTime>(
        showSelectedIcon: false,
        style: kSegmentedStyle,
        segments: [
          for (final e in available.entries)
            if (e.value)
              ButtonSegment(
                value: e.key,
                label: Text(switch (e.key) {
                  _OverTime.cpu => 'CPU',
                  _OverTime.memory => 'Memory',
                  _OverTime.dbCpu => 'DB CPU',
                  _OverTime.rps => 'rps',
                }, style: const TextStyle(fontSize: 12)),
              ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => setState(() => _overTime = s.first),
      ),
      child: Column(
        children: [
          chart,
          const SizedBox(height: 8),
          ChartLegend(backends: [for (final s in series) s.$1]),
        ],
      ),
    );
  }
}

/// The frameworks being compared, each removable.
class _Picked extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;

  const _Picked({required this.state, required this.picked});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final b in picked)
        DockChip(
          key: ValueKey(b.key),
          backend: b,
          onRemove: () => state.toggleCompare(b.key),
        ),
      if (picked.length < DashboardState.maxCompare)
        _AddMenu(state: state, picked: picked),
    ],
  );
}

/// "Add a framework": every framework not picked yet, with its language and
/// its headline in the shown scenario; picking one adds it here.
class _AddMenu extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;

  const _AddMenu({required this.state, required this.picked});

  @override
  Widget build(BuildContext context) {
    final s = state.scenario;
    final metric = state.headline;
    final options = state
        .rank(state.run!.backends, metric, s)
        .where((b) => !picked.contains(b))
        .toList();
    return PopupMenuButton<String>(
      tooltip: 'Add a framework to the comparison',
      color: kCardBgRaised,
      constraints: const BoxConstraints(minWidth: 280, maxHeight: 420),
      onSelected: state.toggleCompare,
      itemBuilder: (context) => [
        for (final b in options)
          PopupMenuItem(
            value: b.key,
            child: Row(
              children: [
                Monogram(backend: b, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.name,
                        style: body(
                          13.5,
                          color: kTextPrimary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        languageLabel(b.language),
                        style: body(11.5, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatMetricShort(metric, state.valueOf(b, metric, s)),
                  style: mono(12.5, color: kTextSecondary),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 15, color: kSignal),
            const SizedBox(width: 6),
            Text(
              'Add a framework',
              style: body(12.5, color: kTextPrimary, weight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// The comparison's answer in one line: who wins how many scenarios on the
/// headline metric, with a win count per framework.
class _Verdict extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;

  const _Verdict({required this.state, required this.picked});

  @override
  Widget build(BuildContext context) {
    final scenarios = state.run!.scenarios;
    final metric = Metrics.headlineFor([
      for (final b in picked) ...b.scenarios.values,
    ]);
    final wins = {for (final b in picked) b.key: 0};
    final ratios = <String, List<double>>{};
    var contested = 0;
    for (final s in scenarios) {
      final v = _RowVerdict.of(
        metric,
        picked,
        (x) => state.valueOf(x, metric, s),
      );
      if (v.values.values.whereType<double>().length < 2) continue;
      contested++;
      final k = v.bestKey;
      if (k == null) continue;
      wins[k] = wins[k]! + 1;
      final rest = v.values.entries
          .where((e) => e.key != k && e.value != null && e.value! > 0)
          .map((e) => v.best! / e.value!)
          .toList();
      if (rest.isNotEmpty) {
        (ratios[k] ??= []).add(rest.reduce((a, b) => a < b ? a : b));
      }
    }
    final ranked = [...picked]
      ..sort((a, b) => wins[b.key]!.compareTo(wins[a.key]!));
    final top = ranked.first;
    final n = wins[top.key]!;
    final label = metric.label[0].toLowerCase() + metric.label.substring(1);
    String x(double v) => v >= 10 ? '${v.round()}' : v.toStringAsFixed(1);
    final r = ratios[top.key];
    final margin = r == null || r.isEmpty
        ? ''
        : () {
            final lo = r.reduce((a, b) => a < b ? a : b);
            final hi = r.reduce((a, b) => a > b ? a : b);
            return x(lo) == x(hi)
                ? ', at least ${x(lo)}× the next pick'
                : ', ${x(lo)}× to ${x(hi)}× the next pick';
          }();
    final shared = ranked.length > 1 && wins[ranked[1].key] == n;
    final line = n == 0
        ? 'No outright winner on $label: every scenario is a tie.'
        : shared
        ? 'Wins are split on $label: '
              '${joinAnd([for (final b in ranked)
                if (wins[b.key] == n) b.name])} win $n each.'
        : '${top.name} wins ${n == contested ? 'all $n' : '$n of $contested'} '
              'scenarios on $label$margin.';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.flag, size: 18, color: kSignal),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  line,
                  style: body(15, color: kTextPrimary, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final b in ranked)
                Container(
                  padding: const EdgeInsets.fromLTRB(4, 3, 9, 3),
                  decoration: BoxDecoration(
                    color: kBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: wins[b.key] == n && n > 0 && !shared
                          ? kSignal.withValues(alpha: 0.6)
                          : kBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Monogram(backend: b, size: 20),
                      const SizedBox(width: 7),
                      Text(b.name, style: body(12.5, color: kTextSecondary)),
                      const SizedBox(width: 8),
                      Text(
                        'W${wins[b.key]}',
                        style: mono(
                          12.5,
                          weight: FontWeight.w700,
                          color: wins[b.key] == n && n > 0 && !shared
                              ? kSignal
                              : kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every picked framework's recorded load steps, replayed as a race in the
/// shown scenario.
class _Replay extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;

  const _Replay({required this.state, required this.picked});

  @override
  Widget build(BuildContext context) {
    final s = state.scenario ?? state.run!.scenarios.first;
    final slo = Slo.of(state.run!.params);
    return SectionCard(
      eyebrow: 'Replay · ${scenarioLabel(s)}',
      title: 'Watch the load climb',
      subtitle:
          'Each framework\'s recorded steps (its median repetition). A step '
          'asks for a fixed rate; it fails at p99 ≥ ${formatMs(slo.p99Ms)}, '
          '≥ ${(slo.errorRate * 100).toStringAsFixed(0)}% errors or under '
          '${(slo.servedRatio * 100).round()}% served. Press play or drag.',
      child: RaceReplay(backends: picked, scenario: s, slo: slo),
    );
  }
}

/// Which values win a row: the best when at least two frameworks have a
/// value and the best is not tied after display rounding; otherwise none.
/// A [neutral] row (a context metric at each framework's own load) never
/// has a best.
class _RowVerdict {
  final Map<String, double?> values;
  final Map<String, String> shown;
  final String? bestKey;
  final double? best;
  final bool tie;
  final bool neutral;

  const _RowVerdict({
    required this.values,
    required this.shown,
    required this.bestKey,
    required this.best,
    required this.tie,
    this.neutral = false,
  });

  static _RowVerdict of(
    Metric m,
    List<BackendResult> backends,
    double? Function(BackendResult) value, {
    bool neutral = false,
  }) {
    final values = {for (final b in backends) b.key: value(b)};
    final shown = {
      for (final e in values.entries) e.key: formatMetricShort(m, e.value),
    };
    final present = values.entries.where((e) => e.value != null).toList();
    if (present.length < 2 || neutral) {
      return _RowVerdict(
        values: values,
        shown: shown,
        bestKey: null,
        best: null,
        tie: false,
        neutral: neutral,
      );
    }
    present.sort(
      (a, b) => m.higherIsBetter
          ? b.value!.compareTo(a.value!)
          : a.value!.compareTo(b.value!),
    );
    final bestEntry = present.first;
    final tie = present
        .skip(1)
        .any((e) => shown[e.key] == shown[bestEntry.key]);
    return _RowVerdict(
      values: values,
      shown: shown,
      bestKey: tie ? null : bestEntry.key,
      best: bestEntry.value,
      tie: tie,
    );
  }

  bool isBest(String key) => bestKey == key;

  /// Bar share, longer is better (the same rule as the leaderboard).
  double share(Metric m, String key) => barShare(m, values[key], best);

  /// The gap to the best ([gapToLeader]), "=" for a tie, "" for the best.
  String delta(Metric m, String key) {
    final v = values[key], b = best;
    if (v == null || b == null) return '';
    if (shown[key] == formatMetricShort(m, b)) return tie ? '=' : '';
    return gapToLeader(m, v, b);
  }
}

/// The highest requested rate every compared framework held (a passing
/// step at the same rate in each one's recorded steps), and each one's
/// step there. Numbers at this load compare like for like.
class _SharedLoad {
  final double rps;
  final Map<String, LoadStep> steps;

  const _SharedLoad(this.rps, this.steps);

  static _SharedLoad? of(DashboardState state, List<BackendResult> bs) {
    Set<double>? common;
    for (final b in bs) {
      final steps = state.resultOf(b)?.steps ?? const [];
      if (steps.isEmpty) return null;
      final held = {
        for (final s in steps)
          if (s.pass) s.targetRps,
      };
      common = common == null ? held : common.intersection(held);
    }
    if (common == null || common.isEmpty) return null;
    final top = common.reduce((a, b) => a > b ? a : b);
    return _SharedLoad(top, {
      for (final b in bs)
        b.key: state
            .resultOf(b)!
            .steps
            .firstWhere((s) => s.pass && s.targetRps == top),
    });
  }
}

/// One row of the side-by-side table.
class _RowSpec {
  final String label;
  final Metric metric;
  final double? Function(BackendResult) value;
  final bool neutral;
  final String help;

  const _RowSpec(
    this.label,
    this.metric,
    this.value, {
    this.neutral = false,
    required this.help,
  });
}

/// Grouped side-by-side table. Desktop: metrics as rows, one column per
/// framework, each value with a bar (longer is better) and its distance
/// from the best. Phone: one block per metric with a lane per framework.
class _Table extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> selected;
  final bool more;
  final VoidCallback onMore;

  const _Table({
    required this.state,
    required this.selected,
    required this.more,
    required this.onMore,
  });

  /// Groups of rows; groups with nothing to show are left out.
  List<(String, String, List<_RowSpec>)> _groups() {
    final rs = selected.map(state.resultOf).whereType<ScenarioResult>();
    final head = Metrics.headlineFor(rs);
    _RowSpec own(Metric m, {bool neutral = false}) => _RowSpec(
      m.labelWithUnit,
      m,
      (b) => m.value(state.resultOf(b)!),
      neutral: neutral,
      help: m.help,
    );
    List<_RowSpec> avail(List<Metric> ms, {bool neutral = false}) => [
      for (final m in Metrics.available(rs, ms)) own(m, neutral: neutral),
    ];
    final shared = _SharedLoad.of(state, selected);
    _RowSpec step(
      _SharedLoad sh,
      String label,
      Metric m,
      double? Function(LoadStep) f,
    ) => _RowSpec(
      '$label at ${compactRps(sh.rps)}',
      m,
      (b) => f(sh.steps[b.key]!),
      help:
          '$label at ${formatRps(sh.rps)} req/s, a rate every framework '
          'here held.',
    );
    return [
      (
        'Throughput',
        'Higher is better. Sustainable load is the headline.',
        avail([head, Metrics.peak]),
      ),
      if (shared != null)
        (
          'At a shared load · ${formatRps(shared.rps)} req/s',
          'The highest step every framework here held, so these compare '
              'like for like. From each one\'s recorded steps (median '
              'repetition). Lower is better.',
          [
            step(shared, 'p99', Metrics.p99, (s) => s.p99),
            step(shared, 'Median', Metrics.p50, (s) => s.p50),
            if (shared.steps.values.every((s) => s.appCpu != null))
              step(shared, 'CPU', Metrics.cpu, (s) => s.appCpu),
            if (shared.steps.values.every((s) => s.appMemMb != null))
              step(shared, 'Memory', Metrics.memory, (s) => s.appMemMb),
          ],
        ),
      (
        'Latency and errors · own load',
        'At each framework\'s own sustainable load: context, not a ranking. '
            'A framework that serves less can show a lower p99, so no best '
            'is marked.',
        avail([
          Metrics.p50,
          Metrics.p99,
          Metrics.errors,
          if (more) ...[Metrics.p90, Metrics.p999],
        ], neutral: true),
      ),
      (
        'Resources · own load',
        'Average over each framework\'s own sustainable step: context, not '
            'a ranking.',
        avail([
          Metrics.cpu,
          Metrics.memory,
          if (more) Metrics.dbCpu,
        ], neutral: true),
      ),
      (
        'Efficiency',
        'Throughput per unit of resource. Higher is better.',
        avail([Metrics.rpsPerCore, if (more) Metrics.rpsPer100Mb]),
      ),
    ].where((g) => g.$3.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups();
    final sha = state.run!.dirty ? null : state.run!.gitSha;
    final impl = <(String, String? Function(BackendResult))>[
      ('Server', (b) => b.implementation?.server),
      ('Concurrency', (b) => b.implementation?.concurrency),
      ('DB access', (b) => b.implementation?.dbAccess),
      ('DB pool', (b) => b.implementation?.pool),
      ('API', (b) => b.apiLabel),
      ('Database', (b) => b.storageLabel),
      ('Versions', (b) => b.subtitle.isEmpty ? null : b.subtitle),
    ];
    return SectionCard(
      eyebrow: 'Every number',
      title: 'Side by side · ${scenarioLabel(state.scenario ?? '')}',
      subtitle:
          'Best value per row in lime; equal values are not ranked. A '
          'longer bar is always better.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) => c.maxWidth < kNarrow
                ? _cards(groups, impl, sha)
                : _table(c.maxWidth, groups, impl, sha),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onMore,
            icon: Icon(more ? Icons.expand_less : Icons.expand_more, size: 16),
            label: Text(more ? 'Fewer rows' : 'More rows'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kSignal,
              side: const BorderSide(color: kBorder),
              textStyle: labelStyle(context, 12.5, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  static final _labelStyle = body(12.5, color: kTextSecondary);
  static final _groupStyle = caps(11, color: kTextPrimary);
  static final _helpStyle = body(11.5, color: kTextMuted);

  Widget _table(
    double width,
    List<(String, String, List<_RowSpec>)> groups,
    List<(String, String? Function(BackendResult))> impl,
    String? sha,
  ) {
    const labelW = 170.0;
    final colW = ((width - labelW) / selected.length).clamp(150.0, 600.0);
    final table = Table(
      columnWidths: {
        0: const FixedColumnWidth(labelW),
        for (var i = 0; i < selected.length; i++) i + 1: FixedColumnWidth(colW),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          children: [
            const SizedBox(height: 32),
            for (final b in selected)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Monogram(backend: b, size: 22),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        b.name,
                        overflow: TextOverflow.ellipsis,
                        style: body(
                          13.5,
                          color: kTextPrimary,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        for (final (title, help, rows) in groups) ...[
          _groupRow(title.toUpperCase(), help),
          for (final r in rows) _metricRow(r),
        ],
        _groupRow(
          'IMPLEMENTATION',
          'How each one is run, so you can judge whether the comparison is '
              'fair.',
        ),
        for (final (label, value) in impl)
          TableRow(
            children: [
              _label(label),
              for (final b in selected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 5, 12, 5),
                  child: Text(
                    value(b) ?? '—',
                    style: body(
                      12.5,
                      color: value(b) == null ? kTextDim : kTextSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
            ],
          ),
        TableRow(
          children: [
            _label('Source'),
            for (final b in selected)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 5, 12, 5),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: b.sourceUrl == null
                      ? Text('—', style: mono(12, color: kTextDim))
                      : SourceLink(
                          url: b.sourceUrlAt(sha) ?? b.sourceUrl!,
                          label: 'backends/${b.path}',
                          fontSize: 12,
                        ),
                ),
              ),
          ],
        ),
      ],
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: table,
    );
  }

  Widget _label(String text, {String? help}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Flexible(child: Text(text, style: _labelStyle)),
        if (help != null) InfoIcon(help),
      ],
    ),
  );

  TableRow _groupRow(String title, String help) => TableRow(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 8, 6),
        child: Text(title, style: _groupStyle),
      ),
      for (var i = 0; i < selected.length; i++)
        i == 0
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 12, 6),
                child: Text(help, style: _helpStyle),
              )
            : const SizedBox.shrink(),
    ],
  );

  TableRow _metricRow(_RowSpec r) {
    final v = _RowVerdict.of(r.metric, selected, r.value, neutral: r.neutral);
    return TableRow(
      children: [
        _label(r.label, help: r.help),
        for (final b in selected)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 5, 12, 5),
            child: _ValueBar(m: r.metric, verdict: v, backend: b),
          ),
      ],
    );
  }

  /// Phone: one block per metric, one lane per framework inside it, so
  /// every framework's number fits the width and reads side by side.
  Widget _cards(
    List<(String, String, List<_RowSpec>)> groups,
    List<(String, String? Function(BackendResult))> impl,
    String? sha,
  ) {
    Widget lane(BackendResult b, Widget value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Monogram(backend: b, size: 18),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 104,
            child: Text(
              b.name,
              maxLines: 2,
              style: body(12, color: kTextSecondary),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: value),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, help, rows) in groups) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 2),
            child: Text(title.toUpperCase(), style: _groupStyle),
          ),
          Text(help, style: _helpStyle),
          for (final r in rows) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(r.label, style: _labelStyle),
            ),
            for (final b in selected)
              lane(
                b,
                _ValueBar(
                  m: r.metric,
                  verdict: _RowVerdict.of(
                    r.metric,
                    selected,
                    r.value,
                    neutral: r.neutral,
                  ),
                  backend: b,
                ),
              ),
          ],
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
          child: Text('IMPLEMENTATION', style: _groupStyle),
        ),
        for (final (label, value) in impl)
          if (selected.any((b) => value(b) != null)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text(label, style: _labelStyle),
            ),
            for (final b in selected)
              lane(
                b,
                Text(
                  value(b) ?? '—',
                  style: body(
                    12.5,
                    color: value(b) == null ? kTextDim : kTextPrimary,
                  ),
                ),
              ),
          ],
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text('Source', style: _labelStyle),
        ),
        for (final b in selected)
          lane(
            b,
            b.sourceUrl == null
                ? Text('—', style: mono(12, color: kTextDim))
                : Align(
                    alignment: Alignment.centerLeft,
                    child: SourceLink(
                      url: b.sourceUrlAt(sha) ?? b.sourceUrl!,
                      label: 'backends/${b.path}',
                      fontSize: 12,
                    ),
                  ),
          ),
      ],
    );
  }
}

/// One table cell: right-aligned value (lime when it is the row's clear
/// best), the distance from the best, and a bar where longer is better.
/// Neutral rows show the value only.
class _ValueBar extends StatelessWidget {
  final Metric m;
  final _RowVerdict verdict;
  final BackendResult backend;

  const _ValueBar({
    required this.m,
    required this.verdict,
    required this.backend,
  });

  @override
  Widget build(BuildContext context) {
    final key = backend.key;
    final value = verdict.values[key];
    final best = verdict.isBest(key);
    final delta = verdict.neutral ? '' : verdict.delta(m, key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (delta.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(delta, style: mono(11, color: kTextMuted)),
              ),
            Text(
              verdict.shown[key]!,
              style: mono(
                13,
                color: value == null
                    ? kTextDim
                    : best
                    ? kSignal
                    : kTextPrimary,
                weight: best ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
        if (!verdict.neutral) ...[
          const SizedBox(height: 3),
          LaneBar(
            fraction: value == null ? 0 : verdict.share(m, key),
            color: BackendColors.of(key).withValues(alpha: best ? 1 : 0.6),
            height: best ? 6 : 4,
          ),
        ],
      ],
    );
  }
}

/// The headline number of every picked framework in every scenario, so the
/// comparison is not limited to the scenario the charts show. One block per
/// scenario with a lane per framework, best first; tapping a block shows
/// that scenario below.
class _AllScenarios extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;

  const _AllScenarios({required this.state, required this.picked});

  @override
  Widget build(BuildContext context) {
    final scenarios = state.run!.scenarios;
    final metric = Metrics.headlineFor([
      for (final b in picked) ...b.scenarios.values,
    ]);
    return SectionCard(
      eyebrow: 'Every scenario',
      title: '${metric.labelWithUnit} in every scenario',
      subtitle:
          'Best first, in lime; equal values are not ranked. Tap a scenario '
          'for the rest of its numbers.',
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 1000
              ? scenarios.length.clamp(1, 4)
              : c.maxWidth >= 560
              ? 2
              : 1;
          const gap = 12.0;
          final w = (c.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final s in scenarios)
                SizedBox(
                  width: w,
                  child: _ScenarioBlock(
                    state: state,
                    picked: picked,
                    metric: metric,
                    scenario: s,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScenarioBlock extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;
  final Metric metric;
  final String scenario;

  const _ScenarioBlock({
    required this.state,
    required this.picked,
    required this.metric,
    required this.scenario,
  });

  @override
  Widget build(BuildContext context) {
    final selected = scenario == state.scenario;
    final verdict = _RowVerdict.of(
      metric,
      picked,
      (x) => state.valueOf(x, metric, scenario),
    );
    final order = state.rank(picked, metric, scenario);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => state.setScenario(scenario),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: motion(context, 180),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected ? kCardBgRaised : kBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? kSignal.withValues(alpha: 0.6) : kBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      scenarioLabel(scenario),
                      style: body(
                        13,
                        color: selected ? kSignal : kTextPrimary,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    Text('SHOWN BELOW', style: caps(10.5, color: kSignal)),
                ],
              ),
              const SizedBox(height: 8),
              RepaintBoundary(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final b in order)
                      FlipOnMove(
                        key: ValueKey('block-$scenario-${b.key}'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Monogram(backend: b, size: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      b.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: body(11.5, color: kTextMuted),
                                    ),
                                    _ValueBar(
                                      m: metric,
                                      verdict: verdict,
                                      backend: b,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
