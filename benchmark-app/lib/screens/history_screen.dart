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

/// Metrics History can plot (they are in index.json's headline data).
final _historyMetrics = [
  Metrics.sustainable,
  Metrics.peak,
  Metrics.p99,
  Metrics.cpu,
  Metrics.memory,
];

/// v1 runs used different scenarios; this is the closest match.
String legacyScenario(String scenario) =>
    scenario.startsWith('no_db') ? 'no_db_test' : 'db_test';

/// One line per backend for one machine+method group.
class HistoryGroup {
  final String groupKey;
  final List<RunIndexEntry> runs;
  final String scenario;
  final Metric metric;
  final List<(String key, String name, List<double?> values)> lines;

  const HistoryGroup({
    required this.groupKey,
    required this.runs,
    required this.scenario,
    required this.metric,
    required this.lines,
  });

  /// Builds the series for [groupKey]. Runs from other machines or methods
  /// never end up in the same group.
  static HistoryGroup build({
    required DashboardState state,
    required String groupKey,
    required String scenario,
    required Metric metric,
    required Map<String, String> names,
  }) {
    final runs = state.historyFor(groupKey);
    final legacy = runs.isNotEmpty && runs.first.isLegacy;
    final sc = legacy ? legacyScenario(scenario) : scenario;
    final m = legacy && metric == Metrics.sustainable ? Metrics.avgRps : metric;
    final keys = <String>{
      for (final r in runs)
        for (final e in r.headline.entries)
          if (e.value[sc]?[m.id] != null) e.key,
    }.toList()..sort();
    return HistoryGroup(
      groupKey: groupKey,
      runs: runs,
      scenario: sc,
      metric: m,
      lines: [
        for (final k in keys)
          (
            k,
            names[k] ?? _nameIn(runs, k),
            [for (final r in runs) r.headline[k]?[sc]?[m.id]],
          ),
      ],
    );
  }
}

String _nameIn(List<RunIndexEntry> runs, String key) {
  for (final r in runs.reversed) {
    final n = r.names[key];
    if (n != null) return n;
  }
  return key;
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Metric _metric = Metrics.sustainable;

  /// Framework highlighted across every chart (tap a legend entry).
  String? _focus;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    final scenario = state.scenario;
    if (run == null || scenario == null) return const SizedBox.shrink();
    final names = {for (final b in run.backends) b.key: b.name};
    final groups = [
      for (final g in state.historyGroups)
        HistoryGroup.build(
          state: state,
          groupKey: g,
          scenario: scenario,
          metric: _metric,
          names: names,
        ),
    ];
    final current = state.index.isEmpty ? null : state.index.first.methodology;
    return PageBody(
      children: [
        PageTitle(
          eyebrow: 'Over time',
          title: 'History',
          subtitle:
              'How results changed across runs. Each chart is one machine '
              'and one test method; numbers are only comparable inside a '
              'chart.',
          onBack: state.goHome,
        ),
        ScenarioTabs(
          label: 'Scenario',
          scenarios: run.scenarios,
          selected: scenario,
          onSelected: state.setScenario,
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('METRIC', style: caps(10.5)),
            SegmentedButton<Metric>(
              showSelectedIcon: false,
              style: kSegmentedStyle,
              segments: [
                for (final m in _historyMetrics)
                  ButtonSegment(
                    value: m,
                    label: Text(
                      m == Metrics.sustainable ? 'Load' : m.short,
                      softWrap: false,
                      style: const TextStyle(fontSize: 12),
                    ),
                    tooltip: m.help,
                  ),
              ],
              selected: {_metric},
              onSelectionChanged: (s) => setState(() => _metric = s.first),
            ),
          ],
        ),
        for (final g in groups) _card(g, current),
      ],
    );
  }

  Widget _card(HistoryGroup g, String? current) {
    final first = g.runs.isEmpty ? null : g.runs.first;
    final lines = g.lines;
    final legacy = first?.isLegacy ?? false;
    final method = first?.methodology ?? '';
    final older = !legacy && current != null && method != current;
    double? last(List<double?> v) =>
        v.lastWhere((x) => x != null, orElse: () => null);
    final legend = [...lines]
      ..sort((a, b) {
        final va = last(a.$3) ?? -1, vb = last(b.$3) ?? -1;
        return g.metric.higherIsBetter ? vb.compareTo(va) : va.compareTo(vb);
      });
    final multi = lines.where((l) => l.$3.whereType<double>().length > 1);
    return SectionCard(
      eyebrow: legacy
          ? 'v1 method · not comparable'
          : older
          ? 'method $method · older method'
          : 'method $method · current method',
      title: first?.machine.label ?? g.groupKey,
      subtitle: [
        '${g.runs.length} run${g.runs.length == 1 ? '' : 's'}',
        '${g.metric.labelWithUnit} · ${scenarioLabel(g.scenario)}',
        if (multi.isEmpty && lines.isNotEmpty)
          'every framework has one run here, so there are no lines yet',
      ].join(' · '),
      child: lines.isEmpty
          ? Text(
              'No results for this scenario.',
              style: body(13, color: kTextMuted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HistoryChart(
                  labels: runAxisLabels(g.runs),
                  lines: lines,
                  highlight: _focus,
                  format: (v) => formatMetricShort(g.metric, v),
                ),
                const SizedBox(height: 12),
                Text('LATEST VALUE · TAP TO HIGHLIGHT', style: caps(10)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final l in legend)
                      _LegendChip(
                        color: BackendColors.of(l.$1),
                        name: l.$2,
                        value: formatMetricShort(g.metric, last(l.$3)),
                        runs: l.$3.whereType<double>().length,
                        selected: _focus == l.$1,
                        dim: _focus != null && _focus != l.$1,
                        onTap: () => setState(
                          () => _focus = _focus == l.$1 ? null : l.$1,
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String name;
  final String value;
  final int runs;
  final bool selected;
  final bool dim;
  final VoidCallback onTap;

  const _LegendChip({
    required this.color,
    required this.name,
    required this.value,
    required this.runs,
    required this.selected,
    required this.dim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedOpacity(
          duration: motion(context, 150),
          opacity: dim ? 0.45 : 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
            decoration: BoxDecoration(
              color: selected ? kCardBgRaised : kBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? color : kBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColorDot(color: color, size: 9),
                const SizedBox(width: 7),
                Text(name, style: body(12.5, color: kTextPrimary)),
                const SizedBox(width: 8),
                Text(value, style: mono(12, weight: FontWeight.w700)),
                if (runs == 1) ...[
                  const SizedBox(width: 6),
                  Text('1 run', style: mono(10.5, color: kTextDim)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
