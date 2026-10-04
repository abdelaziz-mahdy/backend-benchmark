import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    final scenario = state.scenario;
    if (run == null || scenario == null) return const SizedBox.shrink();
    final names = {for (final b in run.backends) b.key: b.name};
    final allowed = state.languages.isEmpty
        ? null
        : {
            for (final b in run.backends)
              if (state.languages.contains(b.language)) b.key,
          };
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
    return PageBody(
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Metric',
              style: TextStyle(color: kTextMuted, fontSize: 12),
            ),
            SegmentedButton<Metric>(
              showSelectedIcon: false,
              style: kSegmentedStyle,
              segments: [
                for (final m in _historyMetrics)
                  ButtonSegment(
                    value: m,
                    label: Text(m.short, style: const TextStyle(fontSize: 12)),
                    tooltip: m.help,
                  ),
              ],
              selected: {_metric},
              onSelectionChanged: (s) => setState(() => _metric = s.first),
            ),
          ],
        ),
        const Text(
          'Each chart is one machine and one test method. Numbers are only '
          'comparable inside a chart.',
          style: TextStyle(color: kTextMuted, fontSize: 12.5),
        ),
        for (final g in groups) _card(g, allowed),
      ],
    );
  }

  Widget _card(HistoryGroup g, Set<String>? allowed) {
    final first = g.runs.isEmpty ? null : g.runs.first;
    final lines = allowed == null
        ? g.lines
        : g.lines.where((l) => allowed.contains(l.$1)).toList();
    final legacy = first?.isLegacy ?? false;
    return SectionCard(
      title:
          '${first?.machine.label ?? g.groupKey}${legacy ? ' · v1 method' : ''}',
      subtitle: [
        '${g.runs.length} run${g.runs.length == 1 ? '' : 's'}',
        '${g.metric.label} · ${scenarioLabel(g.scenario)}',
        if (legacy) 'v1 numbers are not comparable with v2',
      ].join(' · '),
      child: lines.isEmpty
          ? const Text(
              'No results for this scenario and filter.',
              style: TextStyle(color: kTextMuted, fontSize: 12.5),
            )
          : Column(
              children: [
                HistoryChart(
                  dates: [for (final r in g.runs) r.date ?? '?'],
                  lines: lines,
                  format: (v) => formatMetricShort(g.metric, v),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    for (final l in lines)
                      Text(
                        '${l.$2}: ${formatMetricShort(g.metric, l.$3.lastWhere((v) => v != null, orElse: () => null))}',
                        style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
