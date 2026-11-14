import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../app_router.dart';
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
import '../widgets/podium.dart';

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
            title: 'Pick a framework on the leaderboard',
            message: 'Tap a row, then "Full details and charts".',
          ),
        ],
      );
    }
    final result = state.resultOf(backend);
    return PageBody(
      children: [
        PageTitle(
          eyebrow: '${languageLabel(backend.language)} framework',
          title: backend.name,
          subtitle: backend.subtitle.isEmpty ? null : backend.subtitle,
          leading: Monogram(backend: backend, size: 52),
          onBack: state.goHome,
          trailing: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const CopyLinkButton(),
              CompareToggle(state: state, backend: backend, labelled: true),
            ],
          ),
        ),
        ScenarioTabs(
          label: 'Scenario',
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
          _DriverCard(state: state, backend: backend, result: result),
          _tiles(result),
          if (result.steps.isNotEmpty) _stepCharts(state, backend, result),
          _percentiles(backend, result),
          if (!result.timeseries.isEmpty) _resources(run, backend, result),
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

  Widget _tiles(ScenarioResult r) {
    final headline = Metrics.headlineFor([r]);
    final primary = [
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
    final shown = Metrics.available(
      [r],
      [headline, ...primary, if (_more) ...extra],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TileGrid(
          minTileWidth: 160,
          children: [
            for (final m in shown)
              StatTile(
                label: m.label,
                value: formatMetric(m, m.value(r)),
                detail: _range(m, r),
                help: m.help,
                accent: m == headline ? kSignal : null,
              ),
          ],
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _more = !_more),
              icon: Icon(
                _more ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(_more ? 'Fewer metrics' : 'More metrics'),
            ),
            const SizedBox(width: 8),
            if (r.reps > 0)
              Expanded(
                child: Text(
                  '${r.reps} repetition${r.reps == 1 ? '' : 's'}; small text '
                  'under a value is the min–max across them.'
                  '${r.fromRun != null ? '  Measured in run ${r.fromRun}.' : ''}',
                  style: body(11.5, color: kTextDim),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String? _range(Metric m, ScenarioResult r) {
    final s = m.stat(r);
    if (s == null || r.reps < 2 || s.min == s.max) return null;
    return '${formatMetricShort(m, s.min)} – ${formatMetricShort(m, s.max)}';
  }

  Widget _stepCharts(DashboardState state, BackendResult b, ScenarioResult r) {
    final series = [StepSeries(b, r.steps)];
    final sustainable = Metrics.sustainable.value(r);
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        final throughput = SectionCard(
          eyebrow: 'Throughput',
          title: 'Served vs requested, per load step',
          subtitle:
              'Dashed diagonal = served everything. Where the trace drops '
              'below it, the app stopped keeping up.',
          child: StepLoadChart(
            series: series,
            mode: StepChartMode.throughput,
            sustainable: sustainable,
          ),
        );
        final latency = SectionCard(
          eyebrow: 'Latency',
          title: 'p99 per load step',
          subtitle:
              'Red zone = above the 100 ms SLO. Hollow red points failed a '
              'limit; the run stops there.',
          child: StepLoadChart(
            series: series,
            mode: StepChartMode.p99,
            sustainable: sustainable,
          ),
        );
        if (!wide) {
          return Column(
            children: [throughput, const SizedBox(height: 18), latency],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: throughput),
            const SizedBox(width: 18),
            Expanded(child: latency),
          ],
        );
      },
    );
  }

  Widget _percentiles(BackendResult b, ScenarioResult r) {
    final ms = [
      Metrics.p50,
      Metrics.p90,
      Metrics.p99,
      Metrics.p999,
    ].where((m) => m.value(r) != null).toList();
    if (ms.isEmpty) return const SizedBox.shrink();
    final top = ms.map((m) => m.value(r)!).reduce((a, b) => a > b ? a : b);
    // The scale always reaches past the SLO so its line is on the track.
    final max = (top > 100 ? top : 100) * 1.15;
    final color = BackendColors.of(b.key);
    return SectionCard(
      eyebrow: 'Latency',
      title: 'Latency percentiles',
      subtitle: 'At the sustainable load. The red tick is the 100 ms SLO.',
      child: Column(
        children: [
          for (var i = 0; i < ms.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      ms[i].short,
                      style: mono(12, color: kTextMuted),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          InlineBar(
                            value: ms[i].value(r),
                            max: max,
                            color: color,
                            height: 10,
                            stagger: i * 0.1,
                          ),
                          Positioned(
                            left: c.maxWidth * 100 / max - 1,
                            top: -3,
                            child: Container(
                              width: 2,
                              height: 16,
                              color: kRedline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text(
                      formatMs(ms[i].value(r)!),
                      textAlign: TextAlign.right,
                      style: mono(13, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _resources(RunSummary run, BackendResult b, ScenarioResult r) {
    final ts = r.timeseries;
    final v1 = ts.series.containsKey('rps');
    final cores = int.tryParse(run.appCores);
    final charts = <Widget>[
      if (v1)
        SectionCard(
          eyebrow: 'Throughput',
          title: 'Requests per second over time (v1)',
          child: TimeSeriesChart(
            series: [(b, ts)],
            field: 'rps',
            format: formatNumber,
          ),
        ),
      SectionCard(
        eyebrow: 'Resources',
        title: 'App CPU over time',
        subtitle:
            '100% = one core${cores == null || run.isLegacy ? '' : '; the dashed line is the $cores pinned cores'}. '
            'Each load step lasts ${run.params['step_seconds'] ?? 30} s.',
        child: TimeSeriesChart(
          series: [(b, ts)],
          field: 'app_cpu',
          format: (v) => '${v.toStringAsFixed(0)}%',
          ceiling: cores == null || run.isLegacy ? null : cores * 100.0,
          ceilingLabel: '$cores cores',
        ),
      ),
      SectionCard(
        eyebrow: 'Resources',
        title: 'App memory over time',
        subtitle: 'Memory of the app container, whole run.',
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
                if (i > 0) const SizedBox(height: 18),
                charts[i],
              ],
            ],
          );
        }
        return Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final chart in charts)
              SizedBox(width: (c.maxWidth - 18) / 2, child: chart),
          ],
        );
      },
    );
  }
}

/// The result at a glance: position badge, rank sentence, markers, and
/// where this framework sits in the field.
class _DriverCard extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final ScenarioResult result;

  const _DriverCard({
    required this.state,
    required this.backend,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final metric = state.headline;
    final scenario = state.scenario!;
    final rank = state.rankOf(backend, metric, scenario);
    final value = metric.value(result);
    final flags = resultFlags(backend, result);
    final narrow = MediaQuery.sizeOf(context).width < kNarrow;
    final badge = rank == null
        ? const SizedBox.shrink()
        : _PositionBadge(rank: rank, scenario: scenario);
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.label.toUpperCase(),
          style: caps(11, color: kTextSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (value != null)
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: CountUp(
                    value: value,
                    format: (v) => formatMetricShort(metric, v),
                    style: mono(
                      narrow ? 36 : 46,
                      weight: FontWeight.w700,
                      color: kSignal,
                    ),
                  ),
                ),
              ),
            if (unitSuffix(metric).isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 9),
                child: Text(
                  unitSuffix(metric),
                  style: mono(13, color: kTextMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (_rankLine(rank, metric, scenario) case final line?)
          Text(line, style: body(13.5, color: kTextPrimary)),
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: flags),
        ],
      ],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            BackendColors.of(backend.key).withValues(alpha: 0.08),
            kCardBg,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [badge, const SizedBox(height: 12), summary],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 20),
                    badge,
                  ],
                ),
          const SizedBox(height: 18),
          _FieldStrip(
            state: state,
            backend: backend,
            metric: metric,
            scenario: scenario,
          ),
        ],
      ),
    );
  }

  /// "#2 of 6 by sustainable load in No DB · 83% of the best".
  String? _rankLine(Rank? rank, Metric metric, String scenario) {
    if (rank == null) return null;
    final share = rank.shareOfLeader;
    return [
      '${rank.tied > 1 ? 'tied ' : ''}#${rank.position} of ${rank.total} by '
          '${metric.label.toLowerCase()} in ${scenarioLabel(scenario)}',
      if (rank.position == 1)
        rank.tied > 1 ? 'tied with ${rank.tied - 1} others' : 'the best'
      else if (share != null)
        '${(share * 100).round()}% of the best',
    ].join(' · ');
  }
}

class _PositionBadge extends StatelessWidget {
  final Rank rank;
  final String scenario;

  const _PositionBadge({required this.rank, required this.scenario});

  @override
  Widget build(BuildContext context) {
    final first = rank.position == 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: first ? kSignal.withValues(alpha: 0.08) : kCardBgRaised,
            border: Border.all(
              color: first ? kSignal : kBorderStrong,
              width: first ? 3 : 2,
            ),
          ),
          child: Text(
            'P${rank.position}',
            style: mono(
              30,
              weight: FontWeight.w700,
              color: first ? kSignal : kTextPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(rank.tied > 1 ? 'TIED' : 'POSITION', style: caps(10.5)),
            Text('of ${rank.total}', style: mono(16, weight: FontWeight.w700)),
            Text(
              scenarioLabel(scenario).toUpperCase(),
              style: caps(10.5, color: kTextSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// The field on one line: a tick per framework in this scenario, this one
/// drawn in its colour and labelled, so its place is spatial.
class _FieldStrip extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final Metric metric;
  final String scenario;

  const _FieldStrip({
    required this.state,
    required this.backend,
    required this.metric,
    required this.scenario,
  });

  @override
  Widget build(BuildContext context) {
    final field = [
      for (final b in state.backendsIn(scenario))
        if (state.valueOf(b, metric, scenario) case final v?) (b, v),
    ];
    if (field.length < 2) return const SizedBox.shrink();
    final values = field.map((e) => e.$2);
    final hi = values.reduce((a, b) => a > b ? a : b);
    final me = state.valueOf(backend, metric, scenario);
    final color = BackendColors.of(backend.key);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('THE FIELD', style: caps(10)),
            const Spacer(),
            Text(
              metric.higherIsBetter ? 'right is better' : 'left is better',
              style: mono(10.5, color: kTextDim),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            double x(double v) => hi <= 0 ? 0 : (v / hi) * (w - 2);
            return SizedBox(
              height: 46,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 14,
                    child: Container(height: 2, color: kGridLine),
                  ),
                  for (final (b, v) in field)
                    if (b.key != backend.key)
                      Positioned(
                        left: x(v),
                        top: 8,
                        child: Tooltip(
                          message: '${b.name}: ${formatMetric(metric, v)}',
                          child: Container(
                            width: 2,
                            height: 14,
                            color: kTextDim,
                          ),
                        ),
                      ),
                  if (me != null)
                    GrowFraction(
                      fraction: hi <= 0 ? 0 : me / hi,
                      builder: (context, f) => Positioned(
                        left: (f * (w - 2) - 6).clamp(0, w - 12),
                        top: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 12,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Text('0', style: mono(10, color: kTextDim)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Text(
                      formatMetricShort(metric, hi),
                      style: mono(10, color: kTextDim),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Copies a link to what is on screen (the hash route) to the clipboard.
class CopyLinkButton extends StatelessWidget {
  const CopyLinkButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Copy a link to this view',
      icon: const Icon(Icons.link, color: kTextSecondary, size: 20),
      onPressed: () {
        final state = context.read<DashboardState>();
        final base = Uri.base.removeFragment();
        final link = '$base#${locationOf(state)}';
        Clipboard.setData(ClipboardData(text: link));
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Link copied', style: body(13, color: kTextPrimary)),
            backgroundColor: kCardBgRaised,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
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
              labelStyle: body(12.5, color: kTextPrimary),
              backgroundColor: kBackground,
              side: const BorderSide(color: kSignal),
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
        eyebrow: 'Over time',
        title: 'History',
        child: Text(
          runs.isEmpty
              ? 'No earlier runs of ${backend.name} on this machine.'
              : 'Only one run of ${backend.name} on this machine so far; '
                    'later runs will show up here.',
          style: body(13, color: kTextMuted),
        ),
      );
    }
    final metric = Metrics.headlineFor(backend.scenarios.values);
    return SectionCard(
      eyebrow: 'Over time',
      title: 'History · ${metric.labelWithUnit}',
      subtitle:
          'Every run of ${backend.name} on ${entry.machine.cpu}, same method.',
      child: HistoryChart(
        labels: runAxisLabels(runs),
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
