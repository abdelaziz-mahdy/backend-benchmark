import 'package:material_ui/material_ui.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import 'common.dart';
import 'motion.dart';

/// Unit written after a hero number; ms, %, MB carry their own.
String unitSuffix(Metric m) => switch (m.unit) {
  Unit.rps => 'req/s',
  Unit.ratio => m.id == 'rps_per_core' ? 'req/s per core' : 'req/s per 100 MB',
  _ => '',
};

/// "a", "a and b", "a, b and c".
String joinAnd(List<String> items) => switch (items.length) {
  0 => '',
  1 => items.first,
  _ => '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}',
};

/// One scenario's finishing order for the shown metric: who leads, by how
/// much, and who shares the lead. Every number comes from the run.
class ScenarioRace {
  final String scenario;
  final Metric metric;
  final List<BackendResult> ranked; // value present, best first
  final List<double> values;
  final List<int> positions;

  ScenarioRace._(
    this.scenario,
    this.metric,
    this.ranked,
    this.values,
    this.positions,
  );

  factory ScenarioRace.of(DashboardState state, String scenario) {
    final metric = state.metric;
    final ranked = state
        .rank(state.backendsIn(scenario), metric, scenario)
        .where((b) => state.valueOf(b, metric, scenario) != null)
        .toList();
    final values = [
      for (final b in ranked) state.valueOf(b, metric, scenario)!,
    ];
    final positions = <int>[];
    for (var i = 0; i < values.length; i++) {
      positions.add(
        i > 0 && values[i] == values[i - 1] ? positions[i - 1] : i + 1,
      );
    }
    return ScenarioRace._(scenario, metric, ranked, values, positions);
  }

  bool get isEmpty => ranked.isEmpty;

  /// Frameworks sharing first place.
  int get leaders => positions.where((p) => p == 1).length;

  /// The one framework in first place, or null when the lead is shared.
  BackendResult? get soleLeader =>
      ranked.isNotEmpty && leaders == 1 ? ranked.first : null;

  /// The first-placed frameworks all hit the load generator's limit.
  bool get photoFinish =>
      leaders > 1 &&
      ranked.take(leaders).every((b) => b.scenarios[scenario]!.loadgenBound);

  /// Leader's value over the runner-up's (always ≥ 1), when both exist.
  double? get margin {
    if (ranked.length < 2 || leaders > 1) return null;
    final a = values[0], b = values[1];
    if (metric.higherIsBetter) return b <= 0 ? null : a / b;
    return a <= 0 ? null : b / a;
  }

  /// "1.33× ahead of express (bun)" / "5 tied at the load generator's limit".
  /// For context metrics (lower is better, measured at each framework's own
  /// load), where the lowest value ran.
  String get gapLine {
    if (!metric.isRace) {
      final r = ranked.first.scenarios[scenario]!;
      final load = Metrics.headlineFor([r]).value(r);
      return load == null
          ? 'Lowest, at its own sustainable load'
          : 'Lowest, at its own load of ${formatRps(load)} req/s';
    }
    if (ranked.length < 2) return 'Only one framework measured';
    if (leaders > 1) {
      return photoFinish
          ? 'Photo finish: $leaders tied at the load generator\'s limit'
          : '$leaders-way tie for first';
    }
    final next = ranked[1];
    final ratio = leadRatio(metric, values[0], values[1]);
    return '$ratio ahead of ${next.name}';
  }

  /// Bar share for row [i]: longer is always better.
  double share(int i) => barShare(metric, values[i], values.first);
}

/// The answer the leaderboard opens with: who leads where, by how much, and
/// which scenarios are ties. Computed from the podium of every scenario.
class RaceSummary {
  final Metric metric;
  final List<ScenarioRace> races;

  /// The framework that leads the most scenarios on its own, when it leads
  /// at least two and nobody else leads as many.
  final BackendResult? leader;

  /// Scenarios [leader] leads on its own, in run order.
  final List<ScenarioRace> won;

  RaceSummary._(this.metric, this.races, this.leader, this.won);

  factory RaceSummary.of(DashboardState state) {
    final races = [
      for (final s in state.run!.scenarios) ScenarioRace.of(state, s),
    ].where((r) => !r.isEmpty).toList();
    final metric = state.metric;
    if (!metric.isRace) return RaceSummary._(metric, races, null, const []);
    final wins = <String, int>{};
    for (final r in races) {
      final k = r.soleLeader?.key;
      if (k != null) wins[k] = (wins[k] ?? 0) + 1;
    }
    final most = wins.values.fold(0, (a, b) => a > b ? a : b);
    final top = wins.entries.where((e) => e.value == most).toList();
    if (most < 2 || top.length != 1) {
      return RaceSummary._(metric, races, null, const []);
    }
    final key = top.single.key;
    final won = races.where((r) => r.soleLeader?.key == key).toList();
    return RaceSummary._(metric, races, won.first.soleLeader, won);
  }

  /// Scenarios not led outright by [leader].
  List<ScenarioRace> get rest => races.where((r) => !won.contains(r)).toList();

  /// The headline: an answer, not a question.
  String get headline {
    if (!metric.isRace) {
      final label = metric.label[0].toLowerCase() + metric.label.substring(1);
      return 'Lowest $label, each at its own sustainable load';
    }
    final l = leader;
    if (l != null) {
      final db = races.where((r) => r.scenario.startsWith('db')).toList();
      if (won.length == races.length) return '${l.name} leads every scenario';
      if (db.length >= 2 && won.length == db.length && won.every(db.contains)) {
        return '${l.name} leads every database scenario';
      }
      return '${l.name} leads ${won.length} of ${races.length} scenarios';
    }
    final solos = [for (final r in races) ?r.soleLeader];
    if (solos.isEmpty) return 'Ties at the top in every scenario';
    if (races.length == 1) {
      return '${solos.first.name} leads ${scenarioLabel(races.first.scenario)}';
    }
    final distinct = {for (final b in solos) b.key}.length;
    if (distinct == 1) {
      final r = races.firstWhere((r) => r.soleLeader != null);
      return '${r.soleLeader!.name} leads ${scenarioLabel(r.scenario)}; '
          'the other scenarios are ties';
    }
    return '$distinct different leaders across ${races.length} scenarios';
  }

  /// "DB read, DB write and DB mixed: 1.26× to 1.35× ahead of express (bun)."
  String? get marginLine {
    if (won.isEmpty) return null;
    final ms = [for (final r in won) ?r.margin];
    if (ms.isEmpty) return null;
    final lo = ms.reduce((a, b) => a < b ? a : b);
    final hi = ms.reduce((a, b) => a > b ? a : b);
    String x(double v) => v >= 10 ? '${v.round()}' : v.toStringAsFixed(2);
    final by = x(lo) == x(hi) ? '${x(lo)}×' : '${x(lo)}× to ${x(hi)}×';
    final next = {for (final r in won) r.ranked[1].name};
    final whom = next.length == 1 ? next.single : 'the next framework';
    final where = joinAnd([for (final r in won) scenarioLabel(r.scenario)]);
    return '$where: $by ahead of $whom.';
  }

  /// One sentence per scenario whose lead is shared.
  List<String> get tieNotes => [
    for (final r in races)
      if (metric.isRace && r.leaders > 1)
        r.photoFinish
            ? '${scenarioLabel(r.scenario)} is a ${r.leaders}-way photo '
                  'finish at ${formatMetricShort(metric, r.values.first)}: '
                  'all of them hit the load generator\'s limit, so their '
                  'real order is unknown.'
            : '${scenarioLabel(r.scenario)} is a ${r.leaders}-way tie at '
                  '${formatMetricShort(metric, r.values.first)}.',
  ];
}

/// The hero of the leaderboard. When one framework leads most scenarios,
/// one winner card with a tappable chip per scenario it leads, beside a
/// card for each scenario it does not (ties, other winners). Otherwise one
/// card per scenario. Phones show the ranked scenario's card only. Tapping
/// a chip or card ranks the table by that scenario.
class PodiumStrip extends StatelessWidget {
  final DashboardState state;
  final ValueChanged<String> onPick;

  const PodiumStrip({super.key, required this.state, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final summary = RaceSummary.of(state);
    final races = summary.races;
    if (races.isEmpty) return const SizedBox.shrink();
    Widget card(ScenarioRace r, {int index = 0}) => _LaneCard(
      race: r,
      index: index,
      selected: r.scenario == state.sortScenario,
      onTap: () => onPick(r.scenario),
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < kNarrow) {
          final r = races.firstWhere(
            (r) => r.scenario == state.sortScenario,
            orElse: () => races.first,
          );
          return AnimatedSwitcher(
            duration: motion(context, 200),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey('podium-${r.scenario}-${state.metric.id}'),
              child: card(r),
            ),
          );
        }
        final wide = c.maxWidth >= 940;
        final leader = summary.leader;
        if (leader != null) {
          final winner = _WinnerCard(
            leader: leader,
            won: summary.won,
            total: races.length,
            sorted: state.sortScenario,
            onPick: onPick,
          );
          final rest = summary.rest;
          if (rest.isEmpty) return winner;
          final others = [
            for (var i = 0; i < rest.length; i++) card(rest[i], index: i + 1),
          ];
          if (wide) {
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: summary.won.length * 3, child: winner),
                  for (final o in others) ...[
                    const SizedBox(width: 12),
                    Expanded(flex: 3, child: o),
                  ],
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [winner, const SizedBox(height: 12), _pairs(others)],
          );
        }
        final cards = [
          for (var i = 0; i < races.length; i++) card(races[i], index: i),
        ];
        if (wide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        }
        return _pairs(cards);
      },
    );
  }

  /// Cards two to a row, equal height per row; an odd last card takes the
  /// whole row.
  Widget _pairs(List<Widget> cards) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < cards.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 12),
        if (i + 1 < cards.length)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: 12),
                Expanded(child: cards[i + 1]),
              ],
            ),
          )
        else
          cards[i],
      ],
    ],
  );
}

/// The framework that leads most scenarios, with one chip per scenario it
/// leads: the value, the margin and what the scenario tests.
class _WinnerCard extends StatelessWidget {
  final BackendResult leader;
  final List<ScenarioRace> won;
  final int total;
  final String? sorted;
  final ValueChanged<String> onPick;

  const _WinnerCard({
    required this.leader,
    required this.won,
    required this.total,
    required this.sorted,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final color = BackendColors.of(leader.key);
    final meta = [
      languageLabel(leader.language),
      ...leader.subtitle.split(' · '),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: kBorder),
      ),
      // Sized by its content, so the band can stretch to its height.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ChequerBand(thickness: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Monogram(backend: leader, size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'P1 IN ${won.length} OF $total SCENARIOS',
                                style: caps(11, color: kSignal),
                              ),
                              Text(
                                leader.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: display(28, color: color),
                              ),
                              Text(
                                meta,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: body(12, color: kTextMuted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // A row of chips (no LayoutBuilder: this card sits in an
                    // IntrinsicHeight, which needs intrinsic sizes).
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < won.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: _WinChip(
                                race: won[i],
                                stagger: i * 0.08,
                                selected: won[i].scenario == sorted,
                                onTap: () => onPick(won[i].scenario),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One scenario the winner leads: tap to rank the table by it.
class _WinChip extends StatefulWidget {
  final ScenarioRace race;
  final double stagger;
  final bool selected;
  final VoidCallback onTap;

  const _WinChip({
    required this.race,
    required this.stagger,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_WinChip> createState() => _WinChipState();
}

class _WinChipState extends State<_WinChip> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final race = widget.race;
    final m = race.metric;
    final selected = widget.selected;
    final unit = unitSuffix(m);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Rank the table by ${scenarioLabel(race.scenario)}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hover = h),
          onFocusChange: (f) => setState(() => _focus = f),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: motion(context, 180),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            decoration: BoxDecoration(
              color: selected || _hover ? kCardBgRaised : kBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? kSignal.withValues(alpha: 0.75)
                    : (_hover || _focus ? kBorderStrong : kBorder),
                width: _focus ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        scenarioLabel(race.scenario).toUpperCase(),
                        style: caps(12, color: kTextPrimary),
                      ),
                    ),
                    if (selected) const _RankingTag(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  scenarioHelp(race.scenario),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: body(11.5, color: kTextMuted, height: 1.3),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: CountUp(
                          value: race.values.first,
                          format: (v) => formatMetricShort(m, v),
                          style: mono(
                            28,
                            weight: FontWeight.w700,
                            color: kSignal,
                          ),
                        ),
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 5, bottom: 5),
                        child: Text(unit, style: mono(11, color: kTextMuted)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: MarkerIcons(
                        race.ranked.first.scenarios[race.scenario],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LaneBar(
                  fraction: 1,
                  color: BackendColors.of(race.ranked.first.key),
                  height: 5,
                  stagger: widget.stagger,
                  finish: true,
                ),
                if (race.ranked.length > 1) ...[
                  const SizedBox(height: 4),
                  LaneBar(
                    fraction: race.share(1),
                    color: BackendColors.of(
                      race.ranked[1].key,
                    ).withValues(alpha: 0.7),
                    height: 3,
                    stagger: widget.stagger + 0.05,
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  race.gapLine,
                  maxLines: 2,
                  style: body(
                    12,
                    color: kTextSecondary,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankingTag extends StatelessWidget {
  const _RankingTag();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: kSignal,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text('RANKING', style: caps(10.5, color: kSignalInk)),
  );
}

/// One scenario's podium: the winner (or who shares the lead), the margin,
/// and the top three.
class _LaneCard extends StatefulWidget {
  final ScenarioRace race;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  const _LaneCard({
    required this.race,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_LaneCard> createState() => _LaneCardState();
}

class _LaneCardState extends State<_LaneCard> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final race = widget.race;
    final selected = widget.selected;
    final lit = selected || _hover || _focus;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Rank the table by ${scenarioLabel(race.scenario)}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (h) => setState(() => _hover = h),
          onFocusChange: (f) => setState(() => _focus = f),
          borderRadius: BorderRadius.circular(kRadius),
          child: AnimatedContainer(
            duration: motion(context, 200),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: selected ? kCardBgRaised : kCardBg,
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(
                color: selected
                    ? kSignal.withValues(alpha: 0.75)
                    : (lit ? kBorderStrong : kBorder),
                width: _focus ? 2 : 1,
              ),
            ),
            child: race.leaders > 1 && race.metric.isRace
                ? _tie(context, race)
                : _content(context, race),
          ),
        ),
      ),
    );
  }

  Widget _head(ScenarioRace race) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              scenarioLabel(race.scenario).toUpperCase(),
              style: caps(12, color: kTextPrimary, letterSpacing: 1.6),
            ),
          ),
          if (widget.selected) const _RankingTag(),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        scenarioHelp(race.scenario),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: body(11.5, color: kTextMuted, height: 1.3),
      ),
    ],
  );

  /// Shared lead: the tied frameworks crossing the line together.
  Widget _tie(BuildContext context, ScenarioRace race) {
    final m = race.metric;
    final tied = race.ranked.take(race.leaders).toList();
    final unit = unitSuffix(m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _head(race),
        const SizedBox(height: 14),
        SizedBox(
          height: 30,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              const Positioned(
                left: 0,
                right: 0,
                child: ChequerBand(thickness: 8, horizontal: true),
              ),
              Row(
                children: [
                  for (final b in tied.take(8))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message: b.name,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: kCardBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Monogram(backend: b, size: 28),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CountUp(
                  value: race.values.first,
                  format: (v) => formatMetricShort(m, v),
                  style: mono(28, weight: FontWeight.w700),
                ),
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 5, bottom: 5),
                child: Text(unit, style: mono(11, color: kTextMuted)),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          race.photoFinish
              ? '${race.leaders}-way photo finish'
              : '${race.leaders}-way tie',
          style: body(
            14,
            color: race.photoFinish ? kAmber : kTextPrimary,
            weight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          race.photoFinish
              ? 'Every one of them hit the load generator\'s limit, so the '
                    'real order is unknown.'
              : 'Equal after rounding; no single winner.',
          style: body(12, color: kTextSecondary, height: 1.35),
        ),
        const SizedBox(height: 8),
        Text(
          tied.map((b) => b.name).join(' · '),
          style: body(12, color: kTextMuted, height: 1.4),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, ScenarioRace race) {
    final m = race.metric;
    final isRace = m.isRace;
    final winner = race.ranked.first;
    final winnerColor = BackendColors.of(winner.key);
    final top = [
      for (var i = 0; i < race.ranked.length && race.positions[i] <= 3; i++) i,
    ].take(4).toList();
    final unit = unitSuffix(m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _head(race),
        const SizedBox(height: 12),
        Row(
          children: [
            Monogram(backend: winner, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                winner.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: body(16, color: winnerColor, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CountUp(
                  value: race.values.first,
                  format: (v) => formatMetricShort(m, v),
                  style: mono(
                    32,
                    weight: FontWeight.w700,
                    color: isRace ? kSignal : kTextPrimary,
                  ),
                ),
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 6),
                child: Text(unit, style: mono(11.5, color: kTextMuted)),
              ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MarkerIcons(winner.scenarios[race.scenario]),
            ),
          ],
        ),
        Text(
          race.gapLine,
          maxLines: 2,
          style: body(12, color: kTextSecondary, weight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        for (final i in top) ...[
          _PodiumRow(
            race: race,
            index: i,
            stagger: (widget.index * 0.08) + i * 0.06,
          ),
          const SizedBox(height: 5),
        ],
      ],
    );
  }
}

class _PodiumRow extends StatelessWidget {
  final ScenarioRace race;
  final int index;
  final double stagger;

  const _PodiumRow({
    required this.race,
    required this.index,
    required this.stagger,
  });

  @override
  Widget build(BuildContext context) {
    final b = race.ranked[index];
    final pos = race.positions[index];
    final m = race.metric;
    final isRace = m.isRace;
    final r = b.scenarios[race.scenario]!;
    final load = isRace ? null : Metrics.headlineFor([r]).value(r);
    return Row(
      children: [
        SizedBox(
          width: 26,
          child: Text(
            'P$pos',
            style: mono(
              11,
              weight: FontWeight.w700,
              color: pos == 1 && isRace ? kSignal : kTextMuted,
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Text(
            b.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body(12, color: kTextSecondary),
          ),
        ),
        const SizedBox(width: 6),
        if (isRace)
          Expanded(
            flex: 4,
            child: LaneBar(
              fraction: race.share(index),
              color: BackendColors.of(b.key),
              height: 5,
              stagger: stagger,
            ),
          ),
        const SizedBox(width: 6),
        Text(
          formatMetricShort(m, race.values[index]),
          textAlign: TextAlign.right,
          style: mono(11.5, color: kTextPrimary),
        ),
        if (load != null)
          Text(' @ ${formatRps(load)}', style: mono(11, color: kTextMuted)),
      ],
    );
  }
}
