import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/metrics.dart';
import '../../models/plain.dart';
import '../../models/results.dart';
import '../../state/dashboard_state.dart';
import '../../utils/colors.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_constants.dart';
import '../../widgets/calm.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/implementation.dart';
import '../../widgets/race_replay.dart' show Slo;
import '../history_screen.dart' show runDates;

/// Picks the test the chart sections show (shared with History).
class TestPicker extends StatelessWidget {
  final String label;

  const TestPicker({super.key, this.label = 'Test'});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final tests = testsOf(state.run!);
    final selected = state.scenario;
    if (tests.isEmpty || selected == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Txt.of(context).small),
        const SizedBox(height: 6),
        SegmentSwitch<String>(
          label: label,
          options: [for (final s in tests) (s, testInfo(s).short)],
          selected: selected,
          onSelected: state.setScenario,
        ),
      ],
    );
  }
}

/// A titled block inside a fold: a bold title, a muted line, the content.
class ChartBlock extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const ChartBlock({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Txt.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(title, style: t.h3)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: t.small),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Everything the old details page showed for one framework, for the test
/// chosen above it: every measured number with its run range, the load
/// steps, reply times, processor and memory over time, how it is built,
/// and its history on this machine.
class FrameworkCharts extends StatelessWidget {
  final BackendResult backend;

  const FrameworkCharts({super.key, required this.backend});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run!;
    final t = Txt.of(context);
    final b = backend;
    final test = state.scenario;
    final r = test == null ? null : b.scenarios[test];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TestPicker(label: 'Show the charts for'),
        if (r == null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              '${capFirst(b.name)} was not measured in '
              '${test == null ? 'this test' : testInfo(test).inSentence}.',
              style: t.body,
            ),
          )
        else ...[
          ChartBlock(
            title: 'All numbers from this test',
            subtitle: r.reps > 1
                ? 'The middle of ${numberWord(r.reps)} tries, with the lowest '
                      'and highest try after it.'
                : null,
            child: _AllNumbers(result: r, cores: appCoreCount(run)),
          ),
          if (r.fromRun != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Measured on ${longDate(r.fromRun!.split('_').first)}.',
                style: t.small,
              ),
            ),
          if (r.steps.isNotEmpty) ...[
            ChartBlock(
              title: 'Requests handled at each step',
              subtitle:
                  'The dashed line is "handled everything it was asked". '
                  'Where the line drops below it, the framework stopped '
                  'keeping up. Hollow points missed a limit.'
                  "${StepSeries(b, r.steps, capped: r.loadgenBound).anyToolLimited ? " Amber squares stopped at our testing tool's limit, not the framework's." : ''}"
                  '${r.reps > 1 ? ' From one of the ${numberWord(r.reps)} tries, so its numbers can differ a little from the table above.' : ''}',
              child: StepLoadChart(
                series: [StepSeries(b, r.steps, capped: r.loadgenBound)],
                mode: StepChartMode.throughput,
                sustainable: Metrics.sustainable.value(r),
                capped: r.loadgenBound,
              ),
            ),
            ChartBlock(
              title: 'Slow reply time at each step',
              subtitle:
                  '99 of every 100 replies were faster than this. Above the '
                  'red line is too slow.'
                  '${r.reps > 1 ? ' From one of the ${numberWord(r.reps)} tries, so it can differ a little from the table above.' : ''}'
                  "${StepSeries(b, r.steps, capped: r.loadgenBound).anyToolLimited ? " Amber squares stopped at our testing tool's limit, not the framework's." : ''}",
              child: StepLoadChart(
                series: [StepSeries(b, r.steps, capped: r.loadgenBound)],
                mode: StepChartMode.p99,
                sustainable: Metrics.sustainable.value(r),
                capped: r.loadgenBound,
              ),
            ),
          ],
          _Percentiles(backend: b, result: r),
          if (!r.timeseries.isEmpty) ..._overTime(context, run, b, r),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 22),
          child: ImplementationCard(
            backend: b,
            flags: const [],
            runSha: run.gitSha,
            runDirty: run.dirty,
          ),
        ),
        _FrameworkHistory(state: state, backend: b),
      ],
    );
  }

  List<Widget> _overTime(
    BuildContext context,
    RunSummary run,
    BackendResult b,
    ScenarioResult r,
  ) {
    final ts = r.timeseries;
    final cores = appCoreCount(run);
    final seconds = run.params['step_seconds'];
    return [
      if (ts.series.containsKey('rps'))
        ChartBlock(
          title: 'Requests a second over time',
          child: TimeSeriesChart(
            series: [(b, ts)],
            field: 'rps',
            format: whole,
          ),
        ),
      ChartBlock(
        title: 'Processor over time',
        subtitle:
            'How much of its ${numberWord(cores)} processor '
            '${cores == 1 ? 'core' : 'cores'} it used. 100% is '
            '${cores == 1 ? 'that core' : 'all of them'}.'
            '${seconds is num ? ' Each step lasted ${whole(seconds)} seconds.' : ''}',
        child: TimeSeriesChart(
          series: [(b, ts)],
          field: 'app_cpu',
          format: (v) => '${v.toStringAsFixed(0)}%',
          divideBy: cores.toDouble(),
          maxValue: 100,
          ceiling: 100,
          ceilingLabel: cores == 1 ? 'its core' : 'all its cores',
        ),
      ),
      ChartBlock(
        title: 'Memory over time',
        subtitle: 'The whole test, warm-up included.',
        child: TimeSeriesChart(
          series: [(b, ts)],
          field: 'app_mem_mb',
          formatFor: memoryAxisFormatter,
        ),
      ),
    ];
  }
}

/// Every metric the test recorded, in plain words, with the run range.
class _AllNumbers extends StatelessWidget {
  final ScenarioResult result;
  final int cores;

  const _AllNumbers({required this.result, required this.cores});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final metrics = Metrics.available([result], Metrics.all);
    String plain(Metric m, double v) => switch (m.unit) {
      Unit.rps || Unit.ratio => whole(v),
      Unit.ms => msText(v),
      // The app's share of its own cores, as in every other table.
      Unit.cpu when m.id == 'app_cpu' => cpuText(v, cores),
      Unit.cpu => '${whole(v)}%',
      Unit.mb => memText(v),
      Unit.percent => formatMetricShort(m, v),
    };
    // "40,000+": the result hit our testing tool's limit.
    String fmt(Metric m, double v) =>
        m.id == 'sustainable_rps' && result.loadgenBound
        ? '${whole(v)}+'
        : plain(m, v);
    final style = t.body.copyWith(
      fontSize: 15,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final m in metrics)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.line)),
            ),
            child: Tooltip(
              message: metricMeaning(m, context.read<DashboardState>().run!),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(plainMetricLabel(m), style: style)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        fmt(m, m.value(result)!),
                        style: style.copyWith(fontWeight: FontWeight.w700),
                      ),
                      // The range without "+": only the result as a whole
                      // is flagged as the tool's limit, as on other views.
                      if (m.stat(result) case final s?
                          when result.reps > 1 &&
                              plain(m, s.min) != plain(m, s.max))
                        Text(
                          '${plain(m, s.min)} to ${plain(m, s.max)}',
                          style: t.small.copyWith(fontSize: 13),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Reply time percentiles as bars, with the reply-time limit marked.
class _Percentiles extends StatelessWidget {
  final BackendResult backend;
  final ScenarioResult result;

  const _Percentiles({required this.backend, required this.result});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final rows = [
      // The same names as the table above and Method's "Words we use".
      (Metrics.p50, 'Typical reply'),
      (Metrics.p90, '9 in 10 replies'),
      (Metrics.p99, 'Slow reply'),
      (Metrics.p999, '999 in 1,000 replies'),
    ].where((e) => e.$1.value(result) != null).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    final top = rows
        .map((e) => e.$1.value(result)!)
        .reduce((a, b) => a > b ? a : b);
    // The old method had no reply-time limit, so it gets no mark.
    final run = context.read<DashboardState>().run!;
    final double? limit = run.isLegacy ? null : Slo.of(run.params).p99Ms;
    // The scale always reaches past the limit so its mark is on the track.
    final max = (limit != null && limit > top ? limit : top) * 1.15;
    final color = identityColor(p, backend.key);
    return ChartBlock(
      title: 'Reply times',
      subtitle:
          'How fast replies came back '
          '${run.isLegacy ? 'during the old test' : 'at its result'}: half of '
          'them were faster than the first bar, and so on.'
          '${limit == null ? '' : ' The red mark is the ${msText(limit)} limit.'}',
      child: Column(
        children: [
          for (final (i, (m, label)) in rows.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 132, child: Text(label, style: t.small)),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) => Stack(
                        clipBehavior: Clip.none,
                        children: [
                          InlineBar(
                            value: m.value(result),
                            max: max,
                            color: color,
                            height: 10,
                            stagger: i * 0.1,
                          ),
                          if (limit != null)
                            Positioned(
                              left: c.maxWidth * limit / max - 1,
                              top: -3,
                              child: Container(
                                width: 2,
                                height: 16,
                                color: p.danger,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      msText(m.value(result)!),
                      textAlign: TextAlign.right,
                      style: t.num(15),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The framework's result in this test across runs on the same machine
/// and method.
class _FrameworkHistory extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;

  const _FrameworkHistory({required this.state, required this.backend});

  @override
  Widget build(BuildContext context) {
    final t = Txt.of(context);
    // The run on screen, not one loading.
    final entry = state.shownEntry ?? state.entry;
    final test = state.scenario;
    if (entry == null || test == null) return const SizedBox.shrink();
    final runs = state
        .historyFor(entry.groupKey)
        .where((e) => e.headline[backend.key]?[test] != null)
        .toList();
    if (runs.length < 2) {
      return ChartBlock(
        title: 'History',
        child: Text(
          runs.isEmpty
              ? 'No earlier runs of ${backend.name} with this method on '
                    'this computer.'
              : entry.isLegacy
              ? 'The old method ran once; newer runs use a different method, '
                    'so they are not mixed in here.'
              : 'Only one run of ${backend.name} with this method on this '
                    'computer so far; later runs will show up here.',
          style: t.small,
        ),
      );
    }
    final metric = Metrics.headlineFor(backend.scenarios.values);
    return ChartBlock(
      title: 'History',
      subtitle:
          'Every run of ${backend.name} on ${entry.machine.cpu} with the same '
          'method, in ${unitFor(metric)}.',
      child: HistoryChart(
        labels: runDates(runs),
        lines: [
          (
            backend.key,
            backend.name,
            [for (final r in runs) r.headline[backend.key]![test]![metric.id]],
          ),
        ],
        format: (v) => switch (metric.unit) {
          Unit.rps || Unit.ratio => whole(v),
          Unit.ms => msText(v),
          _ => formatMetricShort(metric, v),
        },
      ),
    );
  }
}
