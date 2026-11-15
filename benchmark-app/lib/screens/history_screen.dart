import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/plain.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import '../widgets/calm.dart';
import '../widgets/charts.dart' show HistoryChart;
import '../widgets/prose.dart';
import '../widgets/site_frame.dart' show SiteFooter, SiteWidth;

/// Numbers History can plot (they are in index.json's headline data), with
/// their name on the switch and what they mean.
final _historyMetrics = [
  (Metrics.sustainable, 'Requests a second'),
  (Metrics.peak, 'Most at any step'),
  (Metrics.p99, 'Slow reply'),
  (Metrics.cpu, 'Processor'),
  (Metrics.memory, 'Memory'),
];

String _metricMeaning(Metric m) => switch (m.id) {
  'sustainable_rps' =>
    'The main result: the most requests a second it handled while staying '
        'fast and error-free. Higher is better.',
  'avg_rps' =>
    'Old method: the average requests a second while users were added. '
        'Higher is better.',
  'peak_rps' =>
    'The most requests a second it answered at any step, however slow the '
        'replies were. Higher is better.',
  'p99_ms' =>
    'Slow reply: 99 of every 100 replies came back within this time. Lower '
        'is better.',
  'app_cpu' =>
    'How much processor it used. 100% is one full core. Lower is better.',
  'app_mem_mb' => 'How much memory it used. Lower is better.',
  _ => m.help,
};

/// A number in plain form: "30,000", "12 ms", "150%", "383 MB".
String _fmt(Metric m, double? v) {
  if (v == null) return '—';
  return switch (m.unit) {
    Unit.rps || Unit.ratio => whole(v),
    Unit.ms => msText(v),
    Unit.cpu => '${v.round()}%',
    Unit.mb => memText(v),
    Unit.percent => formatMetricShort(m, v),
  };
}

/// v1 runs used different tests; this is the closest match.
String legacyScenario(String scenario) =>
    scenario.startsWith('no_db') ? 'no_db_test' : 'db_test';

/// The current test closest to a v1 one (a v1 run may be loaded while
/// History shows current runs).
String currentScenario(String scenario) => switch (scenario) {
  'no_db_test' => 'no_db',
  'db_test' => 'db_mixed',
  _ => scenario,
};

/// The date of each run, written out: "5 October 2026", or "5 Oct" when
/// [short]. Runs that share a date are numbered: "4 Oct (2)".
List<String> runDates(List<RunIndexEntry> runs, {bool short = false}) {
  final dates = [for (final r in runs) longDate(r.date)];
  String shorten(String d) {
    final parts = d.split(' ');
    return parts.length == 3 && parts[1].length > 3
        ? '${parts[0]} ${parts[1].substring(0, 3)}'
        : d;
  }

  final seen = <String, int>{};
  return [
    for (final d in dates)
      () {
        final shown = short ? shorten(d) : d;
        if (dates.where((x) => x == d).length < 2) return shown;
        final n = seen[d] = (seen[d] ?? 0) + 1;
        return short ? '$shown ($n)' : '$shown (run $n)';
      }(),
  ];
}

/// One line per framework for one computer + method group.
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

  /// Builds the series for [groupKey]. Runs from other computers or
  /// methods never end up in the same group.
  static HistoryGroup build({
    required DashboardState state,
    required String groupKey,
    required String scenario,
    required Metric metric,
    required Map<String, String> names,
  }) {
    final runs = state.historyFor(groupKey);
    final legacy = runs.isNotEmpty && runs.first.isLegacy;
    final sc = legacy ? legacyScenario(scenario) : currentScenario(scenario);
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
    final p = context.palette;
    final t = Txt(p);
    final names = {for (final b in run.backends) b.key: b.name};
    final langs = {for (final b in run.backends) b.key: b.language};
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
    Widget label(String s) => Text(
      s,
      style: proseStyle(context).copyWith(fontWeight: FontWeight.w700),
    );
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SiteWidth(
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PageHead(
                    icon: Icons.history,
                    title: 'History',
                    lead: 'How the results changed from run to run.',
                    onBack: () => state.setPage(DashboardPage.home),
                  ),
                  const SizedBox(height: 16),
                  const Points([
                    Point(
                      'Each box below',
                      'is one computer and one way of testing.',
                    ),
                    Point(
                      'Compare numbers only inside one box.',
                      'Another computer or method gives different numbers.',
                    ),
                  ]),
                  const SizedBox(height: kSectionGap),
                  label('Test'),
                  const SizedBox(height: 8),
                  SegmentSwitch<String>(
                    label: 'Test',
                    options: [
                      for (final s in run.scenarios) (s, testInfo(s).title),
                    ],
                    icons: {for (final s in run.scenarios) s: testIcon(s)},
                    selected: scenario,
                    onSelected: state.setScenario,
                  ),
                  const SizedBox(height: 8),
                  Text(testInfo(scenario).what, style: t.small),
                  const SizedBox(height: 24),
                  label('Number to show'),
                  const SizedBox(height: 8),
                  SegmentSwitch<Metric>(
                    label: 'Number to show',
                    options: _historyMetrics,
                    selected: _metric,
                    onSelected: (m) => setState(() => _metric = m),
                  ),
                  const SizedBox(height: 8),
                  Text(_metricMeaning(_metric), style: t.small),
                  for (final g in groups) ...[
                    const SizedBox(height: kSectionGap),
                    _card(g, current, langs),
                  ],
                ],
              ),
            ),
          ),
          const SiteFooter(),
        ],
      ),
    );
  }

  Widget _card(HistoryGroup g, String? current, Map<String, String> langs) {
    final p = context.palette;
    final t = Txt(p);
    final first = g.runs.isEmpty ? null : g.runs.first;
    final lines = g.lines;
    final legacy = first?.isLegacy ?? false;
    final method = first?.methodology ?? '';
    final older = !legacy && current != null && method != current;
    // A framework highlighted in another group (or before a switch) that
    // is not in this one must not dim every line here.
    final focus = lines.any((l) => l.$1 == _focus) ? _focus : null;
    String lang(String key) => langs[key] ?? key.split('-').first;
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
    final dates = runDates(g.runs);
    final narrow = MediaQuery.sizeOf(context).width < kNarrow;
    final metricName = _historyMetrics
        .where((m) => m.$1 == g.metric)
        .map((m) => m.$2)
        .firstOrNull;
    final (pillText, pillIcon, pillOn) = legacy
        ? (
            'Old method: cannot be compared with newer runs',
            Icons.history,
            false,
          )
        : older
        ? (
            'Older method (version ${method.replaceFirst('v', '')})',
            Icons.history,
            false,
          )
        : (
            'Current method (version ${method.replaceFirst('v', '')})',
            Icons.check_circle_outline,
            true,
          );
    return Container(
      key: ValueKey('history-${g.groupKey}'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _Pill(text: pillText, icon: pillIcon, on: pillOn),
          ),
          const SizedBox(height: 12),
          SubHead(Icons.computer, first?.machine.cpu ?? g.groupKey, size: 20),
          const SizedBox(height: 4),
          Text(
            [
              if (first != null) ...[
                '${first.machine.cores} cores',
                '${first.machine.ramGb} GB memory',
              ],
              '${g.runs.length} ${g.runs.length == 1 ? 'run' : 'runs'}',
            ].join(' · '),
            style: t.small,
          ),
          const SizedBox(height: 4),
          Text(
            'Showing: ${metricName ?? plainMetricLabel(g.metric)}, in the '
            '"${testInfo(g.scenario).title}" test.',
            style: t.small,
          ),
          const SizedBox(height: 20),
          if (lines.isEmpty)
            Text(
              'No results for this test on this computer.',
              style: proseStyle(context).copyWith(color: p.muted),
            )
          else if (multi.isEmpty)
            _Snapshot(group: g, lines: legend, last: last, lang: lang)
          else ...[
            const SubHead(Icons.trending_up, 'What changed', size: 17),
            const SizedBox(height: 12),
            for (final (i, l) in multi.indexed) ...[
              if (i > 0) const SizedBox(height: 10),
              _Change(
                badge: LangBadge.of(l.$1, lang(l.$1), size: 20),
                name: l.$2,
                values: l.$3,
                dates: dates,
                metric: g.metric,
              ),
            ],
            if (single > 0) ...[
              const SizedBox(height: 12),
              Text(
                '$single of ${lines.length} frameworks have only one run '
                'here so far. They show as single dots.',
                style: t.small,
              ),
            ],
            const SizedBox(height: 24),
            HistoryChart(
              labels: runDates(g.runs, short: narrow),
              lines: lines,
              highlight: focus,
              format: (v) => _fmt(g.metric, v),
            ),
            const SizedBox(height: 20),
            const SubHead(Icons.touch_app_outlined, 'Latest numbers', size: 17),
            const SizedBox(height: 4),
            Text('Tap a name to highlight its line.', style: t.small),
            const SizedBox(height: 12),
            // Natural width, so names are never cut off on a phone.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final l in legend)
                  _LegendChip(
                    key: ValueKey('legend-${g.groupKey}-${l.$1}'),
                    badge: LangBadge.of(l.$1, lang(l.$1), size: 20),
                    color: identityColor(p, l.$1),
                    name: l.$2,
                    value: _fmt(g.metric, last(l.$3)),
                    selected: focus == l.$1,
                    dim: focus != null && focus != l.$1,
                    onTap: () =>
                        setState(() => _focus = focus == l.$1 ? null : l.$1),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Which method a group used.
class _Pill extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool on;

  const _Pill({required this.text, required this.icon, required this.on});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 12, 5),
      decoration: BoxDecoration(
        color: on ? p.accentSoft : p.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: on ? p.accentSoft : p.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: on ? p.accent : p.muted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Txt(p).small.copyWith(
                fontSize: 14,
                height: 1.3,
                color: p.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One framework's first and latest number in a group, with the change.
class _Change extends StatelessWidget {
  final Widget badge;
  final String name;
  final List<double?> values;
  final List<String> dates;
  final Metric metric;

  const _Change({
    required this.badge,
    required this.name,
    required this.values,
    required this.dates,
    required this.metric,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final i0 = values.indexWhere((v) => v != null);
    final i1 = values.lastIndexWhere((v) => v != null);
    final a = values[i0]!, b = values[i1]!;
    final pct = a == 0 ? null : (b - a) / a * 100;
    final better = metric.higherIsBetter ? b > a : b < a;
    final same = _fmt(metric, a) == _fmt(metric, b);
    final tone = same ? p.muted : (better ? p.accent : p.danger);
    final s = proseStyle(context);
    return Wrap(
      spacing: 12,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            const SizedBox(width: 8),
            Text(name, style: s.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_fmt(metric, a), style: t.num(16, weight: FontWeight.w400)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.arrow_forward, size: 15, color: p.muted),
            ),
            Text(_fmt(metric, b), style: t.num(16)),
          ],
        ),
        if (pct != null && !same)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                b > a ? Icons.arrow_upward : Icons.arrow_downward,
                size: 15,
                color: tone,
              ),
              Text(
                '${pct >= 0 ? '+' : '−'}${pct.abs().round()}% '
                '${better ? '(better)' : '(worse)'}',
                style: t.num(15).copyWith(color: tone),
              ),
            ],
          )
        else
          Text('no change', style: t.small),
        Text('${dates[i0]} to ${dates[i1]}', style: t.small),
      ],
    );
  }
}

/// A group where every framework has one run: no time to plot yet, so a
/// ranked snapshot (longer bar is better).
class _Snapshot extends StatelessWidget {
  final HistoryGroup group;
  final List<(String, String, List<double?>)> lines;
  final double? Function(List<double?>) last;
  final String Function(String key) lang;

  const _Snapshot({
    required this.group,
    required this.lines,
    required this.last,
    required this.lang,
  });

  static String _ordinal(int n) {
    final teen = n % 100 >= 11 && n % 100 <= 13;
    final suffix = teen
        ? 'th'
        : switch (n % 10) {
            1 => 'st',
            2 => 'nd',
            3 => 'rd',
            _ => 'th',
          };
    return '$n$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final m = group.metric;
    final best = last(lines.first.$3);
    // Equal values share a place (1st, 2nd, 2nd, 4th).
    final places = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final same = i > 0 && last(lines[i].$3) == last(lines[i - 1].$3);
      places.add(same ? places[i - 1] : i + 1);
    }
    final dates = joinAnd(
      {for (final r in group.runs) longDate(r.date)}.toList(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Points([
          Point(
            'One run each so far,',
            'made on $dates, so there is no line to draw yet.',
          ),
          const Point('Longer bar is better.', 'Ranked from best to worst.'),
        ]),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) {
            final stacked = c.maxWidth < 520;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < lines.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  () {
                    final color = BackendColors.of(lines[i].$1);
                    final place = SizedBox(
                      width: 40,
                      child: Text(
                        _ordinal(places[i]),
                        style: t.small.copyWith(fontWeight: FontWeight.w700),
                      ),
                    );
                    final who = [
                      LangBadge.of(lines[i].$1, lang(lines[i].$1), size: 20),
                      const SizedBox(width: 8),
                    ];
                    final name = Text(
                      lines[i].$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: proseStyle(context).copyWith(height: 1.3),
                    );
                    final value = Text(
                      _fmt(m, last(lines[i].$3)),
                      textAlign: TextAlign.right,
                      style: t.num(15.5),
                    );
                    final bar = SpeedBar(
                      share: barShare(m, last(lines[i].$3), best),
                      color: color,
                      capped: false,
                      height: 10,
                    );
                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              place,
                              ...who,
                              Expanded(child: name),
                              const SizedBox(width: 8),
                              value,
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 40),
                            child: bar,
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        place,
                        ...who,
                        SizedBox(width: 170, child: name),
                        Expanded(child: bar),
                        SizedBox(width: 90, child: value),
                      ],
                    );
                  }(),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Widget badge;
  final Color color;
  final String name;
  final String value;
  final bool selected;
  final bool dim;
  final VoidCallback onTap;

  const _LegendChip({
    super.key,
    required this.badge,
    required this.color,
    required this.name,
    required this.value,
    required this.selected,
    required this.dim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Pressable(
      onTap: onTap,
      radius: 10,
      selected: selected,
      semanticLabel: '$name, $value. Highlight its line.',
      builder: (context, hovered) => AnimatedOpacity(
        duration: motion(context, 150),
        opacity: dim ? 0.6 : 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(
            color: selected || hovered ? p.surface : p.bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? color : p.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                badge,
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(fontSize: 15, height: 1.2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(value, style: t.num(15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
