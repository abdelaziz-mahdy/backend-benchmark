import 'dart:math' as math;

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
import '../widgets/run_switcher.dart' show RunLoadFailedNote;
import '../widgets/site_frame.dart' show SiteFooter, SiteWidth;

/// Numbers History can plot (they are in index.json's headline data), with
/// their name on the switch and what they mean.
final _historyMetrics = [
  (Metrics.sustainable, 'Fast replies a second'),
  (Metrics.peak, 'Most at any step'),
  (Metrics.p99, 'Slow reply'),
  (Metrics.cpu, 'Processor'),
  (Metrics.memory, 'Memory'),
];

String _metricMeaning(Metric m, RunSummary run) => switch (m.id) {
  'sustainable_rps' => metricMeaning(m, run),
  'avg_rps' =>
    'Old method: the average requests a second while users were added. '
        'Higher is better.',
  'peak_rps' =>
    'The most replies a second it gave at any step, however slow they '
        'were. The result only counts steps where replies stayed fast, so '
        'the two can differ.',
  'p99_ms' => 'Slow reply: 99 of every 100 replies came back within this time.',
  'app_cpu' =>
    'How much of its processor cores it used. 100% is all of them (in the '
        'old method, 100% is one core).',
  'app_mem_mb' => 'How much memory it used.',
  _ => m.help,
};

/// A number in plain form: "30,000", "12 ms", "150%", "383 MB".
String _fmt(Metric m, double? v) {
  if (v == null) return '—';
  return switch (m.unit) {
    Unit.rps || Unit.ratio => whole(v),
    Unit.ms => msText(v),
    // Capped at 100%, as cpuText does everywhere else.
    Unit.cpu => '${math.min(100, v.round())}%',
    Unit.mb => memText(v),
    Unit.percent => formatMetricShort(m, v),
  };
}

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

  /// Frameworks whose newest number here hit our testing tool's limit, so
  /// it reads "40,000+" as on every other page.
  final Set<String> capped;

  const HistoryGroup({
    required this.groupKey,
    required this.runs,
    required this.scenario,
    required this.metric,
    required this.lines,
    this.capped = const {},
  });

  /// "40,000+" when [key]'s newest number hit the tool's limit.
  String plus(String key) => capped.contains(key) ? '+' : '';

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
    // Old-method runs gave the app no fixed cores, so their processor stays
    // per core; the current method gives every app the same cores.
    final shown = state.run;
    final cores = legacy
        ? 1
        : shown != null && !shown.isLegacy
        ? appCoreCount(shown)
        : 2;
    final keys = <String>{
      for (final r in runs)
        for (final e in r.headline.entries)
          if (e.value[sc]?[m.id] != null) e.key,
    }.toList()..sort();
    final capped = <String>{
      if (m == Metrics.sustainable)
        for (final k in keys)
          if (runs.reversed
                  .where((r) => r.headline[k]?[sc]?[m.id] != null)
                  .firstOrNull
                  ?.headline[k]?[sc]?['loadgen_bound'] ==
              1.0)
            k,
    };
    return HistoryGroup(
      groupKey: groupKey,
      runs: runs,
      scenario: sc,
      metric: m,
      capped: capped,
      lines: [
        for (final k in keys)
          (
            k,
            // Today's name wherever any run has one, never a v1 folder name.
            names[k] ?? state.nameOf(k),
            [
              for (final r in runs)
                switch (r.headline[k]?[sc]?[m.id]) {
                  // The app processor is recorded per core; shown, as on
                  // every other page, as a share of the app's own cores.
                  final v? when m.id == 'app_cpu' => math.min(100.0, v / cores),
                  final v => v,
                },
            ],
          ),
      ],
    );
  }
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
    final shownTest = state.scenario;
    if (run == null || shownTest == null) return const SizedBox.shrink();
    final tests =
        state.index
            .where((e) => !e.isLegacy && e.scenarios.isNotEmpty)
            .firstOrNull
            ?.scenarios ??
        run.scenarios;
    // The choices come from the newest runs, whatever run the rest of the
    // site shows, so an old run never hides today's tests; the old-method
    // box maps the choice to its closest old test.
    final chosen = state.historyTest;
    final scenario = chosen != null && tests.contains(chosen)
        ? chosen
        : tests.contains(currentScenario(shownTest))
        ? currentScenario(shownTest)
        : tests.firstOrNull;
    if (scenario == null) return const SizedBox.shrink();
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
                  RunLoadFailedNote(state: state, inPlace: false),
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
                  Row(
                    children: [
                      label('Test'),
                      InfoTip(testInfo(scenario).what, size: 17),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SegmentSwitch<String>(
                    label: 'Test',
                    // The short names every other test switch uses.
                    options: [for (final s in tests) (s, testInfo(s).short)],
                    icons: {for (final s in tests) s: testIcon(s)},
                    selected: scenario,
                    // Kept in the URL, so Back, a reload or a shared link
                    // shows the same test.
                    onSelected: state.setHistoryTest,
                  ),
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
                  Text(_metricMeaning(_metric, run), style: t.small),
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

  final _chartKeys = <String, GlobalKey>{};

  Widget _card(HistoryGroup g, String? current, Map<String, String> langs) {
    final chartKey = _chartKeys.putIfAbsent(
      g.groupKey,
      () => GlobalKey(debugLabel: 'history chart ${g.groupKey}'),
    );
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
        final c = g.metric.higherIsBetter ? vb.compareTo(va) : va.compareTo(vb);
        // Equal numbers in name order, as everywhere else on the site.
        return c != 0 ? c : a.$2.compareTo(b.$2);
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
          if (g.capped.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              // Striped ends only exist where this box draws bars.
              multi.isEmpty
                  ? "+ and a striped bar end = hit our testing tool's limit, "
                        'so it may be faster.'
                  : "+ = hit our testing tool's limit, so it may be faster.",
              style: t.small,
            ),
          ],
          const SizedBox(height: 20),
          if (lines.isEmpty)
            Text(
              // Results exist but this number was never recorded (the old
              // method kept fewer), or there are no results for the test.
              g.runs.any(
                    (r) => r.headline.values.any((m) => m[g.scenario] != null),
                  )
                  ? (legacy
                        ? 'The old method did not record this number.'
                        : 'These runs did not record this number.')
                  : 'No results for this test on this computer.',
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
                    value: '${_fmt(g.metric, last(l.$3))}${g.plus(l.$1)}',
                    selected: focus == l.$1,
                    dim: focus != null && focus != l.$1,
                    onTap: () {
                      setState(() => _focus = focus == l.$1 ? null : l.$1);
                      // The chart is under the names: keep it in sight.
                      bringIntoView(chartKey);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Under the names, so a tapped name's line is right below it.
            HistoryChart(
              key: chartKey,
              labels: runDates(g.runs, short: narrow),
              lines: lines,
              highlight: focus,
              format: (v) => _fmt(g.metric, v),
              // A share of its cores never passes 100%.
              top: g.metric.id == 'app_cpu' && !legacy ? 100 : null,
              capped: g.capped,
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
    // Reply times, processor and memory were measured at each run's own
    // result, so a change in them is not "better" or "worse" by itself.
    final race = metric.isRace;
    final tone = same || !race ? p.muted : (better ? p.accent : p.danger);
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
                '${pct >= 0 ? '+' : '−'}${pct.abs().round()}%'
                '${!race
                    ? ''
                    : better
                    ? ' (better)'
                    : ' (worse)'}',
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
    // Only a race (requests a second) gets places and "longer is better";
    // the rest were measured at each framework's own result.
    final race = m.isRace;
    final most = lines
        .map((l) => last(l.$3) ?? 0)
        .fold(0.0, (a, v) => v > a ? v : a);
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
            group.runs.length == 1
                ? 'One run so far,'
                : '${capFirst(numberWord(group.runs.length))} runs on $dates,',
            group.runs.length == 1
                ? 'made on $dates, so there is no line to draw yet.'
                : 'and each framework is in only one of them, so there is no '
                      'line to draw yet.',
          ),
          if (race)
            const Point('Longer bar is better.', 'Ranked from best to worst.')
          else
            const Point(
              'Not a race:',
              'each framework was measured at its own result, so these '
                  'numbers describe it rather than rank it. Longer bar = a '
                  'bigger number.',
            ),
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
                    final place = race
                        ? SizedBox(
                            width: 40,
                            child: Text(
                              _ordinal(places[i]),
                              style: t.small.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : const SizedBox.shrink();
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
                      '${_fmt(m, last(lines[i].$3))}${group.plus(lines[i].$1)}',
                      textAlign: TextAlign.right,
                      style: t.num(15.5),
                    );
                    final bar = SpeedBar(
                      share: race
                          ? barShare(m, last(lines[i].$3), best)
                          : most <= 0
                          ? 0
                          : (last(lines[i].$3) ?? 0) / most,
                      color: color,
                      capped: group.capped.contains(lines[i].$1),
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
