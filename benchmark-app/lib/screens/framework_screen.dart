import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/implementation.dart';

class FrameworkScreen extends StatefulWidget {
  const FrameworkScreen({super.key});

  @override
  State<FrameworkScreen> createState() => _FrameworkScreenState();
}

class _FrameworkScreenState extends State<FrameworkScreen> {
  bool _more = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    final backend = state.detailBackend;
    if (run == null || backend == null) {
      return PageBody(
        children: [
          PageTitle(title: 'No framework selected', onBack: state.goHome),
          const EmptyState(
            icon: Icons.insights_outlined,
            title: 'Pick a framework on the home page',
            message: 'Tap a row, then "Full details and charts".',
          ),
        ],
      );
    }
    final result = state.resultOf(backend);
    final flags = resultFlags(backend, result);
    return PageBody(
      children: [
        PageTitle(
          title: backend.name,
          subtitle: backend.subtitle.isEmpty ? null : backend.subtitle,
          onBack: state.goHome,
          trailing: _CompareAction(state: state, backend: backend),
        ),
        ScenarioChips(
          scenarios: run.scenarios,
          selected: state.scenario,
          onSelected: state.setScenario,
          empty: {
            for (final s in run.scenarios)
              if (!backend.scenarios.containsKey(s)) s,
          },
        ),
        if (result == null)
          _NoResult(state: state, backend: backend)
        else ...[
          _rankCard(state, backend, flags),
          _tiles(result),
          if (result.steps.isNotEmpty) _stepCharts(backend, result),
          _percentiles(result),
          if (!result.timeseries.isEmpty) _resources(backend, result),
        ],
        ImplementationCard(
          backend: backend,
          flags: const [],
          runSha: run.gitSha,
          runDirty: run.dirty,
        ),
        _History(state: state, backend: backend),
      ],
    );
  }

  /// "#2 of 6 by sustainable load in No DB · 83% of the best" with the
  /// flags of this scenario written next to it.
  Widget _rankCard(DashboardState state, BackendResult b, List<Widget> flags) {
    final rankLine = _rankLine(state, b);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [?rankLine, ...flags],
      ),
    );
  }

  /// "#2 of 6 by sustainable load in No DB · 83% of the leader".
  Widget? _rankLine(DashboardState state, BackendResult b) {
    final metric = state.headline;
    final rank = state.rankOf(b, metric, state.scenario);
    if (rank == null) return null;
    final share = rank.shareOfLeader;
    final parts = [
      '${rank.tied > 1 ? 'tied ' : ''}#${rank.position} of ${rank.total} by '
          '${metric.label.toLowerCase()} in ${scenarioLabel(state.scenario!)}',
      if (rank.position == 1)
        rank.tied > 1 ? 'tied with ${rank.tied - 1} others' : 'the best'
      else if (share != null)
        '${(share * 100).round()}% of the best',
    ];
    return Text(
      parts.join(' · '),
      style: const TextStyle(color: kTextPrimary, fontSize: 13),
    );
  }

  Widget _tiles(ScenarioResult r) {
    final headline = Metrics.headlineFor([r]);
    final primary = [
      headline,
      Metrics.peak,
      Metrics.p50,
      Metrics.p99,
      Metrics.cpu,
      Metrics.memory,
    ];
    final extra = [
      Metrics.p90,
      Metrics.p999,
      Metrics.errors,
      Metrics.dbCpu,
      Metrics.rpsPerCore,
      Metrics.rpsPer100Mb,
    ];
    final shown = Metrics.available([r], [...primary, if (_more) ...extra]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TileGrid(
          children: [
            for (final m in shown)
              StatTile(
                label: m.label,
                value: formatMetric(m, m.value(r)),
                detail: _range(m, r),
                help: m.help,
                accent: m == headline ? kGreen : null,
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _more = !_more),
            icon: Icon(_more ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(_more ? 'Fewer metrics' : 'More metrics'),
          ),
        ),
        if (r.reps > 0)
          Text(
            '${r.reps} repetition${r.reps == 1 ? '' : 's'}; '
            'small text under a value is the min–max across them.'
            '${r.fromRun != null ? '  Measured in run ${r.fromRun}.' : ''}',
            style: const TextStyle(color: kTextDim, fontSize: 11.5),
          ),
      ],
    );
  }

  String? _range(Metric m, ScenarioResult r) {
    final s = m.stat(r);
    if (s == null || r.reps < 2 || s.min == s.max) return null;
    return '${formatMetricShort(m, s.min)} – ${formatMetricShort(m, s.max)}';
  }

  Widget _stepCharts(BackendResult b, ScenarioResult r) {
    final series = [StepSeries(b, r.steps)];
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final throughput = SectionCard(
          title: 'Throughput per load step',
          subtitle:
              'Served vs requested rate. The dashed line is "served everything".',
          child: StepLoadChart(series: series, mode: StepChartMode.throughput),
        );
        final latency = SectionCard(
          title: 'p99 latency per load step',
          subtitle: 'Hollow red points missed the SLO; the run stops there.',
          child: StepLoadChart(series: series, mode: StepChartMode.p99),
        );
        if (!wide) {
          return Column(
            children: [throughput, const SizedBox(height: 16), latency],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: throughput),
            const SizedBox(width: 16),
            Expanded(child: latency),
          ],
        );
      },
    );
  }

  Widget _percentiles(ScenarioResult r) {
    final ms = [
      Metrics.p50,
      Metrics.p90,
      Metrics.p99,
      Metrics.p999,
    ].where((m) => m.value(r) != null).toList();
    if (ms.isEmpty) return const SizedBox.shrink();
    final max = ms.map((m) => m.value(r)!).reduce((a, b) => a > b ? a : b);
    return SectionCard(
      title: 'Latency percentiles',
      subtitle: 'At the sustainable load.',
      child: Column(
        children: [
          for (final m in ms)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      m.short,
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: InlineBar(
                      value: m.value(r),
                      max: max,
                      color: kPurple,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      formatMs(m.value(r)!),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: kTextPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _resources(BackendResult b, ScenarioResult r) {
    final ts = r.timeseries;
    final v1 = ts.series.containsKey('rps');
    final charts = <Widget>[
      if (v1)
        SectionCard(
          title: 'Requests per second over time (v1)',
          child: TimeSeriesChart(
            series: [(b, ts)],
            field: 'rps',
            format: formatNumber,
          ),
        ),
      SectionCard(
        title: 'App CPU over time',
        subtitle: '100% = one core. Each load step lasts 30 s.',
        child: TimeSeriesChart(
          series: [(b, ts)],
          field: 'app_cpu',
          format: (v) => '${v.toStringAsFixed(0)}%',
        ),
      ),
      SectionCard(
        title: 'App memory over time',
        child: TimeSeriesChart(
          series: [(b, ts)],
          field: 'app_mem_mb',
          formatFor: memoryAxisFormatter,
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900) {
          return Column(
            children: [
              for (var i = 0; i < charts.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                charts[i],
              ],
            ],
          );
        }
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final chart in charts)
              SizedBox(width: (c.maxWidth - 16) / 2, child: chart),
          ],
        );
      },
    );
  }
}

/// This backend has nothing for the selected scenario: offer the ones it has.
class _NoResult extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;

  const _NoResult({required this.state, required this.backend});

  @override
  Widget build(BuildContext context) {
    final others = state.run!.scenarios
        .where(backend.scenarios.containsKey)
        .toList();
    return SectionCard(
      title:
          '${backend.name} was not measured in '
          '${scenarioLabel(state.scenario!)}',
      subtitle: others.isEmpty
          ? 'It has no results in this run.'
          : 'It has results in these scenarios:',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final s in others)
            ActionChip(
              label: Text(scenarioLabel(s)),
              onPressed: () => state.setScenario(s),
              labelStyle: const TextStyle(fontSize: 12, color: kTextPrimary),
              backgroundColor: kBackground,
              side: const BorderSide(color: kBlue),
            ),
        ],
      ),
    );
  }
}

/// Headline across runs on the same machine and method.
class _History extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;

  const _History({required this.state, required this.backend});

  @override
  Widget build(BuildContext context) {
    final entry = state.entry;
    final scenario = state.scenario;
    if (entry == null || scenario == null) return const SizedBox.shrink();
    final runs = state
        .historyFor(entry.groupKey)
        .where((e) => e.headline[backend.key]?[scenario] != null)
        .toList();
    if (runs.length < 2) {
      return SectionCard(
        title: 'History',
        child: Text(
          runs.isEmpty
              ? 'No earlier runs of ${backend.name} on this machine.'
              : 'Only one run of ${backend.name} on this machine so far; '
                    'later runs will show up here.',
          style: const TextStyle(color: kTextMuted, fontSize: 12.5),
        ),
      );
    }
    final metric = Metrics.headlineFor(backend.scenarios.values);
    return SectionCard(
      title: 'History · ${metric.labelWithUnit}',
      subtitle:
          'Every run of ${backend.name} on ${entry.machine.cpu}, same method.',
      child: HistoryChart(
        dates: [for (final r in runs) r.date ?? '?'],
        lines: [
          (
            backend.key,
            backend.name,
            [
              for (final r in runs)
                r.headline[backend.key]![scenario]![metric.id],
            ],
          ),
        ],
        format: (v) => formatMetricShort(metric, v),
      ),
    );
  }
}

/// "+ Compare" for the open framework; the tray at the bottom takes over.
class _CompareAction extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;

  const _CompareAction({required this.state, required this.backend});

  @override
  Widget build(BuildContext context) {
    final on = state.compareKeys.contains(backend.key);
    return OutlinedButton.icon(
      onPressed: state.canAddCompare(backend.key)
          ? () => state.toggleCompare(backend.key)
          : null,
      icon: Icon(on ? Icons.check : Icons.add, size: 14),
      label: Text(on ? 'Added' : 'Compare'),
      style: OutlinedButton.styleFrom(
        foregroundColor: on ? kBlue : kTextSecondary,
        side: BorderSide(color: on ? kBlue : kBorder),
        visualDensity: VisualDensity.compact,
        textStyle: labelStyle(context, 12),
      ),
    );
  }
}
