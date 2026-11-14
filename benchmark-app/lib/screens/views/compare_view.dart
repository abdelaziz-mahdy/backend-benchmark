import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../app_router.dart';
import '../../models/metrics.dart';
import '../../models/plain.dart';
import '../../models/results.dart';
import '../../state/dashboard_state.dart';
import '../../utils/formatters.dart';
import '../../utils/theme_constants.dart';
import '../../widgets/calm.dart';
import '../../widgets/charts.dart';
import '../../widgets/implementation.dart';
import '../../widgets/race_replay.dart';
import 'framework_charts.dart';
import 'home_nav.dart';

/// The highest requested rate every compared framework held (a passing
/// step at the same rate in each one's recorded steps), and each one's
/// step there. Numbers at this load compare like for like.
class SharedLoad {
  final double rps;
  final Map<String, LoadStep> steps;

  const SharedLoad(this.rps, this.steps);

  static SharedLoad? of(List<BackendResult> bs, String test) {
    Set<double>? common;
    for (final b in bs) {
      final steps = b.scenarios[test]?.steps ?? const [];
      if (steps.isEmpty) return null;
      final held = {
        for (final s in steps)
          if (s.pass) s.targetRps,
      };
      common = common == null ? held : common.intersection(held);
    }
    if (common == null || common.isEmpty) return null;
    final top = common.reduce((a, b) => a > b ? a : b);
    return SharedLoad(top, {
      for (final b in bs)
        b.key: b.scenarios[test]!.steps.firstWhere(
          (s) => s.pass && s.targetRps == top,
        ),
    });
  }
}

/// Compare: up to [DashboardState.maxCompare] frameworks, a plain verdict,
/// each test in words and bars, and the load replay, shared-load numbers
/// and charts folded underneath.
class CompareView extends StatelessWidget {
  const CompareView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run!;
    final nav = HomeNav.of(context);
    final t = Txt.of(context);
    final picked = state.compared;
    final tests = testsOf(run);
    final unit = unitFor(state.headline);
    final byTest = {
      for (final s in tests)
        s: resultsFor(
          run,
          s,
        ).where((r) => state.compareKeys.contains(r.key)).toList(),
    };
    final parked = state.parkedCompare;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('Compare frameworks', style: t.h2)),
        const SizedBox(height: 4),
        Text(
          'Pick up to ${numberWord(DashboardState.maxCompare)} frameworks to '
          'see them side by side.',
          style: t.muted,
        ),
        const SizedBox(height: 14),
        _Picked(state: state, picked: picked),
        if (parked.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${capFirst(joinAnd([for (final k in parked) state.nameOf(k)]))} '
              '${parked.length == 1 ? 'is' : 'are'} not in this run, so '
              '${parked.length == 1 ? 'it is' : 'they are'} left out. '
              '${parked.length == 1 ? 'It comes' : 'They come'} back when you '
              'change to a run that has ${parked.length == 1 ? 'it' : 'them'}.',
              style: t.small,
            ),
          ),
        if (picked.length < 2) ...[
          const SizedBox(height: 18),
          Text(
            picked.isEmpty
                ? 'Select at least two names.'
                : 'Select at least one more name.',
            style: t.body,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in [
                ...run.backends,
              ]..sort((a, c) => a.name.compareTo(c.name)))
                NameChip(
                  label: b.name,
                  mine: state.compareKeys.contains(b.key),
                  semanticLabel: state.compareKeys.contains(b.key)
                      ? '${b.name}, picked'
                      : 'Pick ${b.name}',
                  onTap: () => state.toggleCompare(b.key),
                ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 22),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Semantics(
              liveRegion: true,
              child: Text(compareVerdict(byTest), style: t.answer),
            ),
          ),
          const SizedBox(height: 18),
          for (final s in tests)
            _TestBlock(
              test: s,
              results: byTest[s]!,
              missing: [
                for (final b in picked)
                  if (!byTest[s]!.any((r) => r.key == b.key)) b.name,
              ],
              unit: unit,
              onOpen: nav.open,
            ),
          const SizedBox(height: 26),
          const TestPicker(label: 'The sections below show'),
          const SizedBox(height: 12),
          Fold(
            key: ValueKey('replay-${run.id}'),
            title: 'Watch the load climb',
            subtitle:
                'Replays each framework\'s recorded steps, one rate at a '
                'time.',
            topLine: true,
            child: _Replay(state: state, picked: picked),
          ),
          Fold(
            key: ValueKey('shared-${run.id}'),
            title: 'At a shared load',
            subtitle:
                'Reply times, processor and memory at a rate all of them '
                'handled.',
            child: _Shared(state: state, picked: picked),
          ),
          Fold(
            key: ValueKey('charts-${run.id}'),
            title: 'Charts and all numbers',
            subtitle:
                'The load steps, processor and memory over time, every '
                'measured number side by side, and how each is built.',
            child: _Charts(state: state, picked: picked),
          ),
        ],
        const SizedBox(height: 30),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (picked.isNotEmpty)
              CalmButton(label: 'Clear all', onTap: state.clearCompare),
            if (picked.length >= 2)
              TextLink(
                label: 'Copy a link',
                size: 15.5,
                onTap: () => copyToClipboard(
                  context,
                  '${Uri.base.removeFragment()}#${locationOf(state)}',
                  'Link copied',
                ),
              ),
            CalmButton(
              label: 'See all results',
              onTap: () => nav.go(HomeView.all),
            ),
          ],
        ),
      ],
    );
  }
}

/// The picked frameworks, each removable, and the way to add another.
class _Picked extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;

  const _Picked({required this.state, required this.picked});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final full = picked.length >= DashboardState.maxCompare;
    final others = [
      for (final b in state.run!.backends)
        if (!state.compareKeys.contains(b.key)) b,
    ]..sort((a, c) => a.name.compareTo(c.name));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final b in picked)
              Pressable(
                key: ValueKey('picked-${b.key}'),
                onTap: () => state.toggleCompare(b.key),
                radius: 999,
                semanticLabel: 'Remove ${b.name}',
                builder: (context, hovered) => Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.fromLTRB(13, 0, 8, 0),
                  decoration: BoxDecoration(
                    color: p.accentSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: hovered ? p.accent : p.accentSoft,
                    ),
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          b.name,
                          style: t.body.copyWith(fontSize: 15.5, height: 1.2),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.close, size: 18, color: p.text),
                      ],
                    ),
                  ),
                ),
              ),
            if (!full && picked.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: 'Add a framework',
                position: PopupMenuPosition.under,
                constraints: const BoxConstraints(
                  minWidth: 240,
                  maxHeight: 420,
                ),
                onSelected: state.toggleCompare,
                itemBuilder: (context) => [
                  for (final b in others)
                    PopupMenuItem(
                      value: b.key,
                      child: Text(b.name, style: t.body),
                    ),
                ],
                child: ExcludeFocus(
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: CalmButton(
                        label: 'Add a framework',
                        icon: Icons.add,
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'That is the most you can compare at once '
              '(${DashboardState.maxCompare}). Remove one to add another.',
              style: t.small,
            ),
          ),
      ],
    );
  }
}

/// One test: its name, what it does, a bar per framework and a sentence.
class _TestBlock extends StatelessWidget {
  final String test;
  final List<Result> results;
  final List<String> missing;
  final String unit;
  final void Function(String key) onOpen;

  const _TestBlock({
    required this.test,
    required this.results,
    required this.missing,
    required this.unit,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final info = testInfo(test);
    final max = results.isEmpty
        ? 0.0
        : results.map((r) => r.value).reduce((a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(info.title, style: t.h3)),
          Text(info.what, style: t.small),
          const SizedBox(height: 10),
          for (final r in results)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: MergeSemantics(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final nameW = c.maxWidth < 480 ? 120.0 : 170.0;
                    return Row(
                      children: [
                        SizedBox(
                          width: nameW,
                          child: Text(
                            r.name,
                            style: t.body.copyWith(fontSize: 15.5),
                          ),
                        ),
                        Expanded(
                          child: ExcludeSemantics(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                height: 10,
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: max <= 0
                                      ? 0
                                      : (r.value / max).clamp(0.02, 1.0),
                                  child: ColoredBox(color: p.accent),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 112,
                          child: Text(
                            numberText(r),
                            textAlign: TextAlign.right,
                            style: t.num(15.5),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(compareTestSentence(results), style: t.smallText),
          if (missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${capFirst(joinAnd(missing))} '
                '${missing.length == 1 ? 'was' : 'were'} not measured here.',
                style: t.small,
              ),
            ),
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Numbers are $unit.', style: t.small),
            ),
          ),
        ],
      ),
    );
  }
}

/// The recorded load steps of every picked framework, replayed.
class _Replay extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;

  const _Replay({required this.state, required this.picked});

  @override
  Widget build(BuildContext context) {
    final s = state.scenario;
    final run = state.run!;
    if (s == null) return const SizedBox.shrink();
    final slo = Slo.of(run.params);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Each step asked for a fixed number of requests a second. A step '
          'failed when 99 in 100 replies were not back within '
          '${formatMs(slo.p99Ms)}, when ${(slo.errorRate * 100).round()} in '
          '100 or more failed, or when fewer than '
          '${(slo.servedRatio * 100).round()} in 100 were handled. Press play '
          'or drag the slider.',
          style: Txt.of(context).small,
        ),
        const SizedBox(height: 12),
        RaceReplay(backends: picked, scenario: s, slo: slo),
      ],
    );
  }
}

/// Reply times, processor and memory of every picked framework at the
/// highest rate all of them held.
class _Shared extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;

  const _Shared({required this.state, required this.picked});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final s = state.scenario;
    final shared = s == null ? null : SharedLoad.of(picked, s);
    if (shared == null) {
      return Text(
        'There is no rate that all of them handled in recorded steps in '
        'this test.',
        style: t.body,
      );
    }
    final cores = appCoreCount(state.run!);
    final rows = <(String, String Function(LoadStep))>[
      ('Typical reply', (x) => msText(x.p50)),
      ('Slow reply', (x) => msText(x.p99)),
      if (shared.steps.values.every((x) => x.appCpu != null))
        ('Processor', (x) => cpuText(x.appCpu!, cores)),
      if (shared.steps.values.every((x) => x.appMemMb != null))
        ('Memory', (x) => memText(x.appMemMb!)),
    ];
    final cell = t.body.copyWith(
      fontSize: 14.5,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    Widget c(String text, {bool left = false, bool head = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: left ? TextAlign.left : TextAlign.right,
        style: head ? cell.copyWith(color: p.muted, height: 1.2) : cell,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'All ${numberWord(picked.length)} handled ${whole(shared.rps)} '
          'requests a second. At that same rate, from each one\'s recorded '
          'steps:',
          style: t.body,
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.5)},
          defaultVerticalAlignment: TableCellVerticalAlignment.bottom,
          children: [
            TableRow(
              children: [
                c('Framework', left: true, head: true),
                for (final r in rows) c(r.$1, head: true),
              ],
            ),
            for (final b in picked)
              TableRow(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: p.line)),
                ),
                children: [
                  c(b.name, left: true),
                  for (final r in rows) c(r.$2(shared.steps[b.key]!)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Bullets([
          'Unlike the main numbers, these are at the same rate for all of '
              'them, so they compare like for like. Lower is better.',
          'Typical reply: half of all replies were faster. Slow reply: 99 of '
              'every 100 were faster.',
        ]),
      ],
    );
  }
}

enum _OverTime { cpu, memory, dbCpu, rps }

/// Step charts, resources over time, every number side by side, and how
/// each one is built.
class _Charts extends StatefulWidget {
  final DashboardState state;
  final List<BackendResult> picked;

  const _Charts({required this.state, required this.picked});

  @override
  State<_Charts> createState() => _ChartsState();
}

class _ChartsState extends State<_Charts> {
  _OverTime _mode = _OverTime.cpu;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final t = Txt.of(context);
    final s = state.scenario;
    if (s == null) return const SizedBox.shrink();
    final here = [
      for (final b in widget.picked)
        if (b.scenarios.containsKey(s)) b,
    ];
    if (here.length < 2) {
      return Text(
        'Fewer than two of them were measured in '
        '${testInfo(s).inSentence}.',
        style: t.body,
      );
    }
    final steps = [
      for (final b in here)
        if (b.scenarios[s]!.steps.isNotEmpty)
          StepSeries(b, b.scenarios[s]!.steps),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (steps.isNotEmpty) ...[
          ChartBlock(
            title: 'Requests handled at each step',
            subtitle:
                'Where a line leaves the dashed diagonal, that framework '
                'stopped keeping up.',
            child: Column(
              children: [
                StepLoadChart(series: steps, mode: StepChartMode.throughput),
                const SizedBox(height: 8),
                ChartLegend(backends: [for (final x in steps) x.backend]),
              ],
            ),
          ),
          ChartBlock(
            title: 'Slow reply time at each step',
            subtitle:
                'Above the red line is too slow; hollow points missed '
                'a limit.',
            child: Column(
              children: [
                StepLoadChart(series: steps, mode: StepChartMode.p99),
                const SizedBox(height: 8),
                ChartLegend(backends: [for (final x in steps) x.backend]),
              ],
            ),
          ),
        ],
        _overTime(here, s),
        ChartBlock(
          title: 'All numbers side by side',
          subtitle:
              'Each one at its own result, so only the first rows are a '
              'race. Hover a name for what it means.',
          child: _SideBySide(state: state, picked: here, test: s),
        ),
      ],
    );
  }

  Widget _overTime(List<BackendResult> here, String s) {
    final series = [
      for (final b in here)
        if (!b.scenarios[s]!.timeseries.isEmpty)
          (b, b.scenarios[s]!.timeseries),
    ];
    if (series.isEmpty) return const SizedBox.shrink();
    bool has(String f) => series.any((x) => x.$2.series.containsKey(f));
    final available = {
      _OverTime.cpu: has('app_cpu'),
      _OverTime.memory: has('app_mem_mb'),
      _OverTime.dbCpu: has('db_cpu'),
      _OverTime.rps: has('rps'),
    };
    final mode = available[_mode]! ? _mode : _OverTime.cpu;
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
    return ChartBlock(
      title: 'Over time',
      subtitle:
          'The whole test, warm-up included. Faster frameworks ran more '
          'steps, so their lines are longer. 100% processor is one core.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentSwitch<_OverTime>(
            label: 'Show over time',
            options: [
              for (final e in available.entries)
                if (e.value)
                  (
                    e.key,
                    switch (e.key) {
                      _OverTime.cpu => 'Processor',
                      _OverTime.memory => 'Memory',
                      _OverTime.dbCpu => 'Database',
                      _OverTime.rps => 'Requests',
                    },
                  ),
            ],
            selected: mode,
            onSelected: (m) => setState(() => _mode = m),
          ),
          const SizedBox(height: 12),
          chart,
          const SizedBox(height: 8),
          ChartLegend(backends: [for (final x in series) x.$1]),
        ],
      ),
    );
  }
}

/// Every measured number of the picked frameworks in one test, plus how
/// each one is built and where its source is. Scrolls sideways on a phone.
class _SideBySide extends StatelessWidget {
  final DashboardState state;
  final List<BackendResult> picked;
  final String test;

  const _SideBySide({
    required this.state,
    required this.picked,
    required this.test,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final rs = [for (final b in picked) b.scenarios[test]!];
    final metrics = Metrics.available(rs, Metrics.all);
    final sha = state.run!.dirty ? null : state.run!.gitSha;
    final cell = t.body.copyWith(
      fontSize: 14,
      height: 1.3,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    String fmt(Metric m, double? v) {
      if (v == null) return '—';
      return switch (m.unit) {
        Unit.rps || Unit.ratio => whole(v),
        Unit.ms => msText(v),
        Unit.cpu => '${whole(v)}%',
        Unit.mb => memText(v),
        Unit.percent => formatMetricShort(m, v),
      };
    }

    Widget c(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
      child: child,
    );
    final impl = <(String, String? Function(BackendResult))>[
      ('Server', (b) => b.implementation?.server),
      ('Concurrency', (b) => b.implementation?.concurrency),
      ('Database access', (b) => b.implementation?.dbAccess),
      ('Database connections', (b) => b.implementation?.pool),
      ('How it is called', (b) => b.apiLabel),
      ('Storage', (b) => b.storageLabel),
      ('Versions', (b) => b.subtitle.isEmpty ? null : b.subtitle),
    ];
    final table = Table(
      columnWidths: {
        0: const FixedColumnWidth(170),
        for (var i = 1; i <= picked.length; i++) i: const FixedColumnWidth(150),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            for (final b in picked)
              c(
                Text(
                  b.name,
                  textAlign: TextAlign.right,
                  style: cell.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        for (final m in metrics)
          TableRow(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: p.line)),
            ),
            children: [
              c(
                Tooltip(
                  message: m.help,
                  child: Text(plainMetricLabel(m), style: cell),
                ),
              ),
              for (final b in picked)
                c(
                  Text(
                    fmt(m, m.value(b.scenarios[test]!)),
                    textAlign: TextAlign.right,
                    style: cell,
                  ),
                ),
            ],
          ),
        for (final (label, value) in impl)
          if (picked.any((b) => value(b) != null))
            TableRow(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.line)),
              ),
              children: [
                c(Text(label, style: cell.copyWith(color: p.muted))),
                for (final b in picked)
                  c(Text(value(b) ?? '—', style: cell.copyWith(fontSize: 13))),
              ],
            ),
        TableRow(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.line)),
          ),
          children: [
            c(Text('Source code', style: cell.copyWith(color: p.muted))),
            for (final b in picked)
              c(
                b.sourceUrl == null
                    ? Text('—', style: cell)
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: SourceLink(
                          url: b.sourceUrlAt(sha) ?? b.sourceUrl!,
                          label: 'backends/${b.path}',
                          fontSize: 13,
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
}
