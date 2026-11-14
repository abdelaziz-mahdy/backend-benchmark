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
    final multi = lines
        .where((l) => l.$3.whereType<double>().length > 1)
        .toList();
    final single = lines.length - multi.length;
    final labels = runAxisLabels(g.runs);
    final narrow = MediaQuery.sizeOf(context).width < kNarrow;
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
      ].join(' · '),
      child: lines.isEmpty
          ? Text(
              'No results for this scenario.',
              style: body(13, color: kTextMuted),
            )
          : multi.isEmpty
          ? _Snapshot(group: g, lines: legend, last: last)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('WHAT CHANGED', style: caps(11)),
                const SizedBox(height: 6),
                for (final l in multi)
                  _Change(
                    color: BackendColors.of(l.$1),
                    name: l.$2,
                    values: l.$3,
                    labels: labels,
                    metric: g.metric,
                  ),
                if (single > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '$single of ${lines.length} frameworks have one run '
                      'here so far; they show as single dots.',
                      style: body(12, color: kTextMuted),
                    ),
                  ),
                const SizedBox(height: 14),
                HistoryChart(
                  labels: narrow
                      ? [for (final r in g.runs) _commitOrDate(r)]
                      : labels,
                  lines: lines,
                  highlight: _focus,
                  format: (v) => formatMetricShort(g.metric, v),
                ),
                const SizedBox(height: 12),
                Text('LATEST VALUE · TAP TO HIGHLIGHT', style: caps(10.5)),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, c) {
                    final two = c.maxWidth < 560;
                    final w = (c.maxWidth - 6) / 2;
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final l in legend)
                          SizedBox(
                            width: two ? w : null,
                            child: _LegendChip(
                              color: BackendColors.of(l.$1),
                              name: l.$2,
                              value: formatMetricShort(g.metric, last(l.$3)),
                              selected: _focus == l.$1,
                              dim: _focus != null && _focus != l.$1,
                              onTap: () => setState(
                                () => _focus = _focus == l.$1 ? null : l.$1,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }

  /// The commit for runs made from one ("3ae75a8"), else the date.
  static String _commitOrDate(RunIndexEntry r) {
    final parts = r.id.split('_');
    return parts.length >= 3 ? parts[2] : (r.date ?? '?');
  }
}

/// One framework's first and latest value in a group, with the change.
class _Change extends StatelessWidget {
  final Color color;
  final String name;
  final List<double?> values;
  final List<String> labels;
  final Metric metric;

  const _Change({
    required this.color,
    required this.name,
    required this.values,
    required this.labels,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final i0 = values.indexWhere((v) => v != null);
    final i1 = values.lastIndexWhere((v) => v != null);
    final a = values[i0]!, b = values[i1]!;
    final pct = a == 0 ? null : (b - a) / a * 100;
    final better = metric.higherIsBetter ? b > a : b < a;
    final same = formatMetricShort(metric, a) == formatMetricShort(metric, b);
    final tone = same ? kTextMuted : (better ? kSignal : kRedline);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ColorDot(color: color, size: 9),
              const SizedBox(width: 7),
              Text(
                name,
                style: body(13.5, color: kTextPrimary, weight: FontWeight.w600),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMetricShort(metric, a),
                style: mono(13, color: kTextSecondary),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 5),
                child: Icon(Icons.arrow_forward, size: 13, color: kTextMuted),
              ),
              Text(
                formatMetricShort(metric, b),
                style: mono(13, weight: FontWeight.w700),
              ),
            ],
          ),
          if (pct != null && !same)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  b > a ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 13,
                  color: tone,
                  semanticLabel: better ? 'better' : 'worse',
                ),
                Text(
                  '${pct >= 0 ? '+' : '−'}${pct.abs().round()}%',
                  style: mono(12.5, color: tone, weight: FontWeight.w700),
                ),
              ],
            ),
          Text(
            '${labels[i0]} to ${labels[i1]}',
            style: mono(11, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

/// A group where every framework has one run: no time to plot yet, so a
/// ranked snapshot (longer bar is better).
class _Snapshot extends StatelessWidget {
  final HistoryGroup group;
  final List<(String, String, List<double?>)> lines;
  final double? Function(List<double?>) last;

  const _Snapshot({
    required this.group,
    required this.lines,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final m = group.metric;
    final best = last(lines.first.$3);
    // Equal values share a position (1, 2, 2, 4).
    final positions = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final same = i > 0 && last(lines[i].$3) == last(lines[i - 1].$3);
      positions.add(same ? positions[i - 1] : i + 1);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Each framework has one run here so far '
          '(${runAxisLabels(group.runs).join('; ')}), so there is nothing to '
          'draw over time yet. Ranked, longer is better:',
          style: body(12.5, color: kTextMuted),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    'P${positions[i]}',
                    style: mono(
                      11.5,
                      color: kTextMuted,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                ColorDot(color: BackendColors.of(lines[i].$1), size: 9),
                const SizedBox(width: 7),
                SizedBox(
                  width: 130,
                  child: Text(
                    lines[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(12.5, color: kTextSecondary),
                  ),
                ),
                Expanded(
                  child: LaneBar(
                    fraction: barShare(m, last(lines[i].$3), best),
                    color: BackendColors.of(lines[i].$1),
                    height: 6,
                    stagger: i * 0.03,
                  ),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    formatMetricShort(m, last(lines[i].$3)),
                    textAlign: TextAlign.right,
                    style: mono(12.5, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String name;
  final String value;
  final bool selected;
  final bool dim;
  final VoidCallback onTap;

  const _LegendChip({
    required this.color,
    required this.name,
    required this.value,
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
          opacity: dim ? 0.6 : 1,
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
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(12.5, color: kTextPrimary),
                  ),
                ),
                const SizedBox(width: 8),
                Text(value, style: mono(12, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
