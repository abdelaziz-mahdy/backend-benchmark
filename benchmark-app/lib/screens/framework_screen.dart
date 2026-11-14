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
          _tiles(state, backend, result),
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

  Widget _tiles(DashboardState state, BackendResult b, ScenarioResult r) {
    final headline = Metrics.headlineFor([r]);
    final lead = _leadTile(state, b, headline);
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
    // The headline is in the card above; the tiles add what it does not.
    final shown = Metrics.available([r], [...primary, if (_more) ...extra]);
    final narrow = MediaQuery.sizeOf(context).width < kNarrow;
    final from = r.fromRun;
    final caption = r.reps <= 0
        ? null
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text:
                      '${r.reps} repetition${r.reps == 1 ? '' : 's'}; small '
                      'text under a value is the min–max across them.',
                ),
                if (from != null) ...[
                  const TextSpan(text: '  Measured in '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: Tooltip(
                      message: from,
                      child: Text(
                        'run ${shortRunId(from)}',
                        style: mono(11, color: kTextMuted),
                      ),
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ],
            ),
            style: body(11.5, color: kTextMuted),
          );
    final toggle = TextButton.icon(
      onPressed: () => setState(() => _more = !_more),
      icon: Icon(_more ? Icons.expand_less : Icons.expand_more, size: 18),
      label: Text(_more ? 'Fewer metrics' : 'More metrics'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TileGrid(
          minTileWidth: 160,
          children: [
            ?lead,
            for (final m in shown)
              StatTile(
                label: m.label,
                value: formatMetric(m, m.value(r)),
                detail: _range(m, r),
                help: m.help,
              ),
          ],
        ),
        if (narrow || caption == null) ...[
          Align(alignment: Alignment.centerLeft, child: toggle),
          ?caption,
        ] else
          Row(
            children: [
              toggle,
              const SizedBox(width: 8),
              Expanded(child: caption),
            ],
          ),
      ],
    );
  }

  /// "Lead over P2 1.33×" for the leader, "Gap to P1 2.5×" for the rest,
  /// from the same ranking the card above uses.
  Widget? _leadTile(DashboardState state, BackendResult b, Metric m) {
    final n = _Neighbours.of(state, b, m, state.scenario!);
    if (n == null) return null;
    final me = n.value;
    if (n.position == 1 && n.tied > 1) {
      return StatTile(
        label: 'Tied for P1',
        value: '${n.tied}-way',
        detail: 'equal ${formatMetricShort(m, me)}',
        help: 'Shares first place with ${n.tied - 1} others.',
      );
    }
    if (n.position == 1) {
      final next = n.below;
      if (next == null) return null;
      return StatTile(
        label: 'Lead over P${n.belowPosition}',
        value: leadRatio(m, me, next.$2),
        detail: 'vs ${next.$1.name} ${formatMetricShort(m, next.$2)}',
        accent: kSignal,
        help: 'This framework\'s value over the next one\'s.',
      );
    }
    return StatTile(
      label: 'Gap to P1',
      value: leadRatio(m, n.leader.$2, me),
      detail: '${n.leader.$1.name} ${formatMetricShort(m, n.leader.$2)}',
      help: 'The leader\'s value over this framework\'s.',
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
              'limit; after the first failure the run probes between the '
              'last pass and the first fail. Amber points failed because the '
              'load generator itself was the limit.',
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

/// Where a framework sits in one scenario: its position, the leader, and
/// the nearest frameworks ahead of and behind it (ties skipped).
class _Neighbours {
  final int position;
  final int tied;
  final double value;
  final (BackendResult, double) leader;
  final (BackendResult, double)? above;
  final (BackendResult, double)? below;
  final int belowPosition;

  const _Neighbours({
    required this.position,
    required this.tied,
    required this.value,
    required this.leader,
    required this.above,
    required this.below,
    required this.belowPosition,
  });

  static _Neighbours? of(
    DashboardState state,
    BackendResult b,
    Metric m,
    String s,
  ) {
    final ranked = [
      for (final x in state.rank(state.backendsIn(s), m, s))
        if (state.valueOf(x, m, s) case final v?) (x, v),
    ];
    final i = ranked.indexWhere((e) => e.$1.key == b.key);
    if (i < 0) return null;
    final me = ranked[i].$2;
    final first = ranked.indexWhere((e) => e.$2 == me);
    final last = ranked.lastIndexWhere((e) => e.$2 == me);
    return _Neighbours(
      position: first + 1,
      tied: last - first + 1,
      value: me,
      leader: ranked.first,
      above: first > 0 ? ranked[first - 1] : null,
      below: last + 1 < ranked.length ? ranked[last + 1] : null,
      belowPosition: last + 2,
    );
  }
}

/// The result at a glance: the headline number, who is just ahead and
/// behind (with a one-tap comparison), markers, the position badge and the
/// whole field on one labelled line. An identity stripe, no wash of colour.
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
    final identity = BackendColors.of(backend.key);
    final n = _Neighbours.of(state, backend, metric, scenario);
    final badge = rank == null
        ? const SizedBox.shrink()
        : _PositionBadge(rank: rank, scenario: scenario);
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${metric.label.toUpperCase()} · ${scenarioLabel(scenario).toUpperCase()}',
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
                      color: rank?.position == 1 ? kSignal : kTextPrimary,
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
        if (n != null) ...[
          const SizedBox(height: 6),
          _RivalLine(state: state, backend: backend, metric: metric, n: n),
        ],
        if (flags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: flags),
        ],
      ],
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: identity, width: 4),
            top: BorderSide(color: identity.withValues(alpha: 0.35)),
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
      ),
    );
  }
}

/// "Ahead of express (bun) by 1.33×", or "Behind X by 2.5× · ahead of Y by
/// 1.03×": names open their details, and one tap compares with the rival.
class _RivalLine extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final Metric metric;
  final _Neighbours n;

  const _RivalLine({
    required this.state,
    required this.backend,
    required this.metric,
    required this.n,
  });

  @override
  Widget build(BuildContext context) {
    final style = body(14, color: kTextPrimary);
    Widget link(BackendResult b) => InkWell(
      onTap: () => state.openDetails(b.key),
      borderRadius: BorderRadius.circular(4),
      child: Text(
        b.name,
        style: body(
          14,
          color: BackendColors.of(b.key),
          weight: FontWeight.w700,
        ).copyWith(decoration: TextDecoration.underline),
      ),
    );
    final parts = <Widget>[];
    final rival = n.position == 1 ? n.below?.$1 : n.above?.$1;
    if (n.position == 1 && n.tied > 1) {
      parts.add(
        Text(
          'Tied for P1 with '
          '${n.tied == 2 ? 'one other' : '${n.tied - 1} others'}',
          style: style,
        ),
      );
    } else if (n.position == 1 && n.below != null) {
      parts.addAll([
        Text('Ahead of ', style: style),
        link(n.below!.$1),
        Text(' by ${leadRatio(metric, n.value, n.below!.$2)}', style: style),
      ]);
    } else if (n.above != null) {
      parts.addAll([
        Text('Behind ', style: style),
        link(n.above!.$1),
        Text(' by ${leadRatio(metric, n.above!.$2, n.value)}', style: style),
      ]);
      if (n.below != null) {
        parts.addAll([
          Text('  ·  ahead of ', style: style),
          link(n.below!.$1),
          Text(' by ${leadRatio(metric, n.value, n.below!.$2)}', style: style),
        ]);
      }
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: [
        ...parts,
        if (rival != null) ...[
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () {
              if (state.comparePair(backend.key, rival.key)) return;
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(
                    'The comparison is full: remove one to add these two.',
                    style: body(13, color: kTextPrimary),
                  ),
                  backgroundColor: kCardBgRaised,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.compare_arrows, size: 15),
            label: Text('Compare with ${rival.name}'),
            style: OutlinedButton.styleFrom(
              foregroundColor: kTextPrimary,
              side: const BorderSide(color: kBorderStrong),
              visualDensity: VisualDensity.compact,
              textStyle: labelStyle(context, 12.5, weight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
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
            Text(rank.tied > 1 ? 'TIED' : 'POSITION', style: caps(11)),
            Text('of ${rank.total}', style: mono(16, weight: FontWeight.w700)),
            Text(
              scenarioLabel(scenario).toUpperCase(),
              style: caps(11, color: kTextSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// The field on one line: every framework of the scenario as a monogram at
/// its value (tap to open it), frameworks at the same spot stacked, this
/// one raised and labelled with its value.
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
      for (final b in state.rank(state.backendsIn(scenario), metric, scenario))
        if (state.valueOf(b, metric, scenario) case final v?) (b, v),
    ];
    if (field.length < 2) return const SizedBox.shrink();
    final hi = field.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final me = state.valueOf(backend, metric, scenario);
    const dot = 20.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('THE FIELD · TAP ONE TO OPEN IT', style: caps(11)),
            const Spacer(),
            Text(
              metric.higherIsBetter ? 'right is better' : 'left is better',
              style: mono(11, color: kTextMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            double x(double v) =>
                hi <= 0 ? 0 : (v / hi * (w - dot)).clamp(0, w - dot);
            // Stack frameworks whose dots would overlap.
            final placed = <(BackendResult, double, double, int)>[];
            for (final (b, v) in field.reversed) {
              final px = x(v);
              var level = 0;
              while (placed.any(
                (p) => p.$4 == level && (p.$3 - px).abs() < dot + 2,
              )) {
                level++;
              }
              placed.add((b, v, px, level));
            }
            final levels = placed
                .map((p) => p.$4)
                .fold(0, (a, b) => a > b ? a : b);
            final myLevel = placed
                .where((p) => p.$1.key == backend.key)
                .map((p) => p.$4)
                .fold(0, (a, b) => a > b ? a : b);
            final height = 22 + (levels + 1) * (dot + 4) + 16;
            final mine = me == null ? null : x(me);
            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16 + dot / 2,
                    child: Container(height: 2, color: kBorder),
                  ),
                  for (final (b, v, px, level) in placed)
                    Positioned(
                      left: px,
                      bottom: 16 + level * (dot + 4),
                      child: _FieldDot(
                        backend: b,
                        label: '${b.name}: ${formatMetric(metric, v)}',
                        me: b.key == backend.key,
                        size: dot,
                        onTap: () => state.openDetails(b.key),
                      ),
                    ),
                  if (mine != null)
                    Positioned(
                      left: (mine + dot / 2 - 60).clamp(0, w - 120),
                      bottom: 16 + (myLevel + 1) * (dot + 4) + 2,
                      width: 120,
                      child: Text(
                        formatMetricShort(metric, me!),
                        // Over the marker; flush with an edge near one.
                        textAlign: mine + dot / 2 - 60 > w - 120
                            ? TextAlign.right
                            : mine + dot / 2 - 60 < 0
                            ? TextAlign.left
                            : TextAlign.center,
                        style: mono(
                          14,
                          weight: FontWeight.w700,
                          color: BackendColors.of(backend.key),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Text('0', style: mono(11, color: kTextMuted)),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Text(
                      formatMetricShort(metric, hi),
                      style: mono(11, color: kTextMuted),
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

class _FieldDot extends StatelessWidget {
  final BackendResult backend;
  final String label;
  final bool me;
  final double size;
  final VoidCallback onTap;

  const _FieldDot({
    required this.backend,
    required this.label,
    required this.me,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = BackendColors.of(backend.key);
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: me ? '$label (this framework)' : 'Open $label',
        excludeSemantics: true,
        child: InkWell(
          onTap: me ? null : onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: me
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  )
                : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(6),
                border: me ? Border.all(color: color, width: 2) : null,
              ),
              child: Monogram(backend: backend, size: size),
            ),
          ),
        ),
      ),
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
