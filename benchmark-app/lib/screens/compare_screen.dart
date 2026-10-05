import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/implementation.dart';

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
          title: picked.length < 2
              ? 'Compare'
              : picked.map((b) => b.name).join(' vs '),
          subtitle: picked.length < 2
              ? null
              : 'Remove one with ×, add more from the home page.',
          onBack: state.goHome,
        ),
        _Picked(state: state, picked: picked),
        if (picked.length < 2)
          const EmptyState(
            icon: Icons.compare_arrows,
            title: 'Pick at least two frameworks to compare',
            message:
                'On the home page, tap "Compare" on a row or open a row '
                'and tap "Compare with the leaders".',
          )
        else ...[
          _AllScenarios(state: state, picked: picked),
          ScenarioChips(
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
          title: 'Throughput per load step',
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
          title: 'p99 latency per load step',
          subtitle: 'Above the orange line the SLO is missed.',
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
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final b in picked)
        InputChip(
          avatar: ColorDot(color: BackendColors.of(b.key), size: 9),
          label: Text(b.name),
          labelStyle: const TextStyle(color: kTextPrimary, fontSize: 12.5),
          backgroundColor: kCardBg,
          side: const BorderSide(color: kBorder),
          deleteIconColor: kTextMuted,
          deleteButtonTooltipMessage: 'Remove ${b.name}',
          visualDensity: VisualDensity.compact,
          onDeleted: () => state.toggleCompare(b.key),
        ),
      if (picked.length < DashboardState.maxCompare)
        ActionChip(
          avatar: const Icon(Icons.add, size: 14, color: kTextMuted),
          label: const Text('Add from the list'),
          labelStyle: const TextStyle(color: kTextMuted, fontSize: 12.5),
          backgroundColor: kBackground,
          side: const BorderSide(color: kBorder),
          visualDensity: VisualDensity.compact,
          onPressed: state.goHome,
        ),
    ],
  );
}

/// Which values win a row: the best when at least two frameworks have a
/// value and the best is not tied after display rounding; otherwise none.
class _RowVerdict {
  final Map<String, double?> values;
  final Map<String, String> shown;
  final String? bestKey;
  final double? best;
  final double max;
  final bool tie;

  const _RowVerdict({
    required this.values,
    required this.shown,
    required this.bestKey,
    required this.best,
    required this.max,
    required this.tie,
  });

  static _RowVerdict of(
    Metric m,
    List<BackendResult> backends,
    double? Function(BackendResult) value,
  ) {
    final values = {for (final b in backends) b.key: value(b)};
    final shown = {
      for (final e in values.entries) e.key: formatMetricShort(m, e.value),
    };
    final present = values.entries.where((e) => e.value != null).toList();
    if (present.length < 2) {
      return _RowVerdict(
        values: values,
        shown: shown,
        bestKey: null,
        best: null,
        max: present.isEmpty ? 0 : present.first.value!,
        tie: false,
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
    final max = present.map((e) => e.value!).reduce((a, b) => a > b ? a : b);
    return _RowVerdict(
      values: values,
      shown: shown,
      bestKey: tie ? null : bestEntry.key,
      best: bestEntry.value,
      max: max,
      tie: tie,
    );
  }

  bool isBest(String key) => bestKey == key;

  /// "−42%" for a smaller higher-is-better value, "2.3× slower" / "1.8× more"
  /// for a larger lower-is-better one, "=" for a tie, "" for the best.
  String delta(Metric m, String key) {
    final v = values[key], b = best;
    if (v == null || b == null) return '';
    if (shown[key] == formatMetricShort(m, b)) return tie ? '=' : '';
    if (m.higherIsBetter) {
      if (b <= 0) return '';
      return '−${((1 - v / b) * 100).round()}%';
    }
    if (b <= 0) return '';
    final x = v / b;
    final word = m.unit == Unit.ms ? 'slower' : 'more';
    return '${x >= 10 ? x.round() : x.toStringAsFixed(1)}× $word';
  }
}

/// Grouped side-by-side table. Desktop: metrics as rows, one column per
/// framework, each value with a bar scaled to the row's largest value and
/// its distance from the best. Phone: one card per framework.
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

  static const _groups = <(String, String)>[
    ('Throughput', 'Higher is better. Sustainable load is the headline.'),
    (
      'Latency and errors',
      'At each framework\'s own sustainable load, so a slower framework can '
          'show a lower p99 by serving less. Lower is better.',
    ),
    ('Resources', 'Average over the sustainable step. Lower is better.'),
    ('Efficiency', 'Throughput per unit of resource. Higher is better.'),
  ];

  /// Group title, help, and its metrics (the secondary ones only with
  /// [more]); groups with nothing to show are left out.
  List<(String, String, List<Metric>)> _rows(Iterable<ScenarioResult> rs) {
    final head = Metrics.headlineFor(rs);
    final by = <String, (List<Metric>, List<Metric>)>{
      'Throughput': ([head, Metrics.peak], []),
      'Latency and errors': (
        [Metrics.p50, Metrics.p99, Metrics.errors],
        [Metrics.p90, Metrics.p999],
      ),
      'Resources': ([Metrics.cpu, Metrics.memory], [Metrics.dbCpu]),
      'Efficiency': ([Metrics.rpsPerCore], [Metrics.rpsPer100Mb]),
    };
    return [
      for (final (title, help) in _groups)
        (
          title,
          help,
          Metrics.available(rs, [...by[title]!.$1, if (more) ...by[title]!.$2]),
        ),
    ].where((g) => g.$3.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final results = selected.map(state.resultOf).whereType<ScenarioResult>();
    final groups = _rows(results);
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
      title: 'Side by side · ${scenarioLabel(state.scenario ?? '')}',
      subtitle:
          'Best value per row in green; equal values are not ranked. Bars '
          'show each value against the largest in its row.',
      trailing: TextButton.icon(
        onPressed: onMore,
        icon: Icon(more ? Icons.expand_less : Icons.expand_more, size: 16),
        label: Text(more ? 'Fewer rows' : 'More rows'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: labelStyle(context, 12),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth < kNarrow
            ? _cards(groups, impl, sha)
            : _table(c.maxWidth, groups, impl, sha),
      ),
    );
  }

  static const _labelStyle = TextStyle(color: kTextSecondary, fontSize: 12.5);
  static const _groupStyle = TextStyle(
    color: kTextPrimary,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  );
  static const _helpStyle = TextStyle(color: kTextDim, fontSize: 11);

  Widget _table(
    double width,
    List<(String, String, List<Metric>)> groups,
    List<(String, String? Function(BackendResult))> impl,
    String? sha,
  ) {
    const labelW = 150.0;
    final colW = ((width - labelW) / selected.length).clamp(150.0, 320.0);
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
                    ColorDot(color: BackendColors.of(b.key), size: 8),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        b.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        for (final (title, help, metrics) in groups) ...[
          _groupRow(title, help),
          for (final m in metrics) _metricRow(m),
        ],
        _groupRow(
          'Implementation',
          'How each one is run, so you can judge whether the comparison is '
              'fair.',
        ),
        for (final (label, value) in impl)
          TableRow(
            children: [
              _label(label),
              for (final b in selected)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 5, 12, 5),
                  child: Text(
                    value(b) ?? '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: value(b) == null ? kTextDim : kTextSecondary,
                      fontSize: 12,
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
                padding: const EdgeInsets.fromLTRB(0, 5, 12, 5),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: b.sourceUrl == null
                      ? const Text('—', style: TextStyle(color: kTextDim))
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

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Text(text, style: _labelStyle),
  );

  TableRow _groupRow(String title, String help) => TableRow(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 6),
        child: Text(title, style: _groupStyle),
      ),
      for (var i = 0; i < selected.length; i++)
        i == 0
            ? Padding(
                padding: const EdgeInsets.fromLTRB(0, 18, 12, 6),
                child: Text(help, style: _helpStyle),
              )
            : const SizedBox.shrink(),
    ],
  );

  TableRow _metricRow(Metric m) {
    final v = _RowVerdict.of(m, selected, (b) => m.value(state.resultOf(b)!));
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Tooltip(
            message: m.help,
            waitDuration: const Duration(milliseconds: 400),
            child: Text(m.labelWithUnit, style: _labelStyle),
          ),
        ),
        for (final b in selected)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 5, 12, 5),
            child: _ValueBar(m: m, verdict: v, backend: b),
          ),
      ],
    );
  }

  /// Phone: one card per framework with the same groups.
  Widget _cards(
    List<(String, String, List<Metric>)> groups,
    List<(String, String? Function(BackendResult))> impl,
    String? sha,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in selected)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: kBackground,
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BackendLabel(backend: b),
                for (final (title, _, metrics) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                    child: Text(title, style: _groupStyle),
                  ),
                  for (final m in metrics)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(m.labelWithUnit, style: _labelStyle),
                          ),
                          Expanded(
                            child: _ValueBar(
                              m: m,
                              verdict: _RowVerdict.of(
                                m,
                                selected,
                                (x) => m.value(state.resultOf(x)!),
                              ),
                              backend: b,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 12, 0, 4),
                  child: Text('Implementation', style: _groupStyle),
                ),
                for (final (label, value) in impl)
                  if (value(b) != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(label, style: _labelStyle),
                          ),
                          Expanded(child: factText(value(b)!)),
                        ],
                      ),
                    ),
                if (b.sourceUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: SourceLink(
                      url: b.sourceUrlAt(sha) ?? b.sourceUrl!,
                      label: 'backends/${b.path}',
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One table cell: right-aligned value (green when it is the row's clear
/// best), the distance from the best, and a thin bar for magnitude.
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
    final delta = verdict.delta(m, key);
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
                child: Text(
                  delta,
                  style: const TextStyle(color: kTextDim, fontSize: 11),
                ),
              ),
            Text(
              verdict.shown[key]!,
              style: TextStyle(
                color: value == null
                    ? kTextDim
                    : best
                    ? kGreen
                    : kTextPrimary,
                fontSize: 13,
                fontWeight: best ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        InlineBar(
          value: value,
          max: verdict.max,
          color: BackendColors.of(key).withValues(alpha: 0.7),
          height: 4,
        ),
      ],
    );
  }
}

/// The headline number of every picked framework in every scenario, so the
/// comparison is not limited to the scenario the charts show.
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
      title: '${metric.labelWithUnit} in every scenario',
      subtitle:
          'Best per scenario in green; equal values are not ranked. '
          'Tap a scenario for the rest of its numbers.',
      fullBleed: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Table(
            defaultColumnWidth: const FixedColumnWidth(150),
            columnWidths: const {0: FixedColumnWidth(96)},
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: kBorder)),
                ),
                children: [
                  const SizedBox(height: 30),
                  for (final b in picked)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ColorDot(color: BackendColors.of(b.key), size: 8),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              b.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: kTextPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              for (final s in scenarios)
                TableRow(
                  children: [
                    InkWell(
                      onTap: () => state.setScenario(s),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          scenarioLabel(s),
                          style: TextStyle(
                            color: s == state.scenario
                                ? kTextPrimary
                                : kTextSecondary,
                            fontSize: 12.5,
                            fontWeight: s == state.scenario
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    for (final b in picked)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 5, 12, 5),
                        child: _ValueBar(
                          m: metric,
                          verdict: _RowVerdict.of(
                            metric,
                            picked,
                            (x) => state.valueOf(x, metric, s),
                          ),
                          backend: b,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
