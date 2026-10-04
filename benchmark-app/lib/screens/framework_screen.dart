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
      return const PageBody(
        children: [
          EmptyState(
            icon: Icons.insights_outlined,
            title: 'No framework to show',
            message: 'This scenario has no results.',
          ),
        ],
      );
    }
    final result = state.resultOf(backend);
    return PageBody(
      children: [
        _Picker(state: state, run: run, selected: backend),
        if (result == null)
          EmptyState(
            icon: Icons.block,
            title:
                '${backend.name} has no ${scenarioLabel(state.scenario!)} result',
            message: 'Pick another scenario above.',
          )
        else ...[
          _tiles(result),
          if (result.steps.isNotEmpty) _stepCharts(backend, result),
          _percentiles(result),
          if (!result.timeseries.isEmpty) _resources(backend, result),
        ],
        _AcrossScenarios(state: state, backend: backend),
        _History(state: state, backend: backend),
      ],
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
          format: (v) => '${formatNumber(v)} MB',
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

class _Picker extends StatelessWidget {
  final DashboardState state;
  final RunSummary run;
  final BackendResult selected;

  const _Picker({
    required this.state,
    required this.run,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final backends = [...run.backends]
      ..sort((a, b) => a.name.compareTo(b.name));
    final flags = resultFlags(selected, state.resultOf(selected));
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected.key,
              isExpanded: true,
              dropdownColor: kCardBg,
              padding: const EdgeInsets.symmetric(vertical: 6),
              icon: const Icon(Icons.expand_more, color: kTextMuted),
              items: [
                for (final b in backends)
                  DropdownMenuItem(
                    value: b.key,
                    child: BackendLabel(backend: b, fontSize: 14),
                  ),
              ],
              selectedItemBuilder: (_) => [
                for (final b in backends)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BackendLabel(backend: b, fontSize: 15),
                  ),
              ],
              onChanged: (k) => state.setDetail(k!),
            ),
          ),
        ),
        ...flags,
        if (selected.notes != null)
          Text(
            selected.notes!,
            style: const TextStyle(color: kTextMuted, fontSize: 12),
          ),
      ],
    );
  }
}

/// This framework's headline across every scenario of the run.
class _AcrossScenarios extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;

  const _AcrossScenarios({required this.state, required this.backend});

  @override
  Widget build(BuildContext context) {
    final scenarios = state.run!.scenarios
        .where(backend.scenarios.containsKey)
        .toList();
    if (scenarios.length < 2) return const SizedBox.shrink();
    final metric = Metrics.headlineFor(backend.scenarios.values);
    final values = {
      for (final s in scenarios) s: metric.value(backend.scenarios[s]!),
    };
    final max = values.values.whereType<double>().fold(
      0.0,
      (a, b) => a > b ? a : b,
    );
    return SectionCard(
      title: '${metric.label} by scenario',
      subtitle: 'Tap a scenario to switch to it.',
      child: Column(
        children: [
          for (final s in scenarios)
            InkWell(
              onTap: () => state.setScenario(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        scenarioLabel(s),
                        style: TextStyle(
                          color: s == state.scenario
                              ? kTextPrimary
                              : kTextMuted,
                          fontSize: 12.5,
                          fontWeight: s == state.scenario
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    Expanded(
                      child: InlineBar(
                        value: values[s],
                        max: max,
                        color: BackendColors.of(backend.key),
                      ),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        formatMetric(metric, values[s]),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
      title: 'History · ${metric.label}',
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
