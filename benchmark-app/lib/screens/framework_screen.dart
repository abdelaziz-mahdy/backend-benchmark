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
        _Finder(state: state, selected: backend),
        ImplementationCard(
          backend: backend,
          flags: resultFlags(backend, result),
          runSha: run.gitSha,
          runDirty: run.dirty,
          rankLine: result == null ? null : _rankLine(state, backend),
        ),
        if (result == null)
          _NoResult(state: state, backend: backend)
        else ...[
          _tiles(result),
          _AcrossScenarios(state: state, backend: backend),
          if (result.steps.isNotEmpty) _stepCharts(backend, result),
          _percentiles(result),
          if (!result.timeseries.isEmpty) _resources(backend, result),
        ],
        _History(state: state, backend: backend),
      ],
    );
  }

  /// "#2 of 6 by sustainable load in No DB · 83% of the leader".
  Widget? _rankLine(DashboardState state, BackendResult b) {
    final metric = state.headline;
    final rank = state.rankOf(b, metric);
    if (rank == null) return null;
    final share = rank.shareOfLeader;
    final parts = [
      '${rank.tied > 1 ? 'tied ' : ''}#${rank.position} of ${rank.total} by '
          '${metric.label.toLowerCase()} in ${scenarioLabel(state.scenario!)}',
      if (rank.position == 1)
        rank.tied > 1 ? 'tied with ${rank.tied - 1} others' : 'the leader'
      else if (share != null)
        '${(share * 100).round()}% of the leader',
    ];
    return Text(
      parts.join(' · '),
      style: const TextStyle(color: kTextSecondary, fontSize: 12.5),
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

/// Type-ahead over every backend of the run, plus previous/next.
class _Finder extends StatefulWidget {
  final DashboardState state;
  final BackendResult selected;

  const _Finder({required this.state, required this.selected});

  @override
  State<_Finder> createState() => _FinderState();
}

class _FinderState extends State<_Finder> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.selected.name;
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else {
        _controller.text = widget.selected.name;
      }
    });
  }

  @override
  void didUpdateWidget(covariant _Finder old) {
    super.didUpdateWidget(old);
    if (old.selected.key != widget.selected.key && !_focus.hasFocus) {
      _controller.text = widget.selected.name;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final all = state.allBackends;
    return Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: RawAutocomplete<BackendResult>(
              textEditingController: _controller,
              focusNode: _focus,
              displayStringForOption: (b) => b.name,
              optionsBuilder: (v) {
                // Everything while the selected name is still in the field.
                if (!_focus.hasFocus || v.text == widget.selected.name) {
                  return all;
                }
                return all.where((b) => b.matches(v.text));
              },
              onSelected: (b) {
                state.setDetail(b.key);
                _focus.unfocus();
              },
              fieldViewBuilder: (context, controller, focus, onSubmit) =>
                  TextField(
                    controller: controller,
                    focusNode: focus,
                    onSubmitted: (text) {
                      final hits = all.where((b) => b.matches(text)).toList();
                      if (hits.isNotEmpty) state.setDetail(hits.first.key);
                      focus.unfocus();
                    },
                    style: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Find a framework',
                      hintStyle: const TextStyle(color: kTextDim),
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 18,
                        color: kTextMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: kCardBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kBlue),
                      ),
                    ),
                  ),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  color: kCardBgRaised,
                  elevation: 6,
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxHeight: 320,
                      maxWidth: 420,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        for (final b in options)
                          InkWell(
                            onTap: () => onSelected(b),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: BackendLabel(backend: b, fontSize: 13.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Previous framework',
          onPressed: all.length > 1 ? () => state.stepDetail(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next framework',
          onPressed: all.length > 1 ? () => state.stepDetail(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
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
