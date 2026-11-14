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

  /// The first-placed frameworks all hit the load generator's limit.
  bool get photoFinish =>
      leaders > 1 &&
      ranked.take(leaders).every((b) => b.scenarios[scenario]!.loadgenBound);

  /// "1.33× ahead of express (bun)" / "5 tied at the load generator's limit".
  String get gapLine {
    if (ranked.length < 2) return 'Only one framework measured';
    if (leaders > 1) {
      return photoFinish
          ? 'Photo finish: $leaders tied at the load generator\'s limit'
          : '$leaders-way tie for first';
    }
    final next = ranked[1];
    final ratio = leadRatio(metric, values[0], values[1]);
    return metric.higherIsBetter
        ? '$ratio ahead of ${next.name}'
        : '$ratio lower than ${next.name}';
  }

  /// Bar share for row [i]: longer is always better.
  double share(int i) {
    final v = values[i], best = values.first;
    if (metric.higherIsBetter) return best <= 0 ? 0 : v / best;
    return v <= 0 ? 1 : (best / v).clamp(0, 1);
  }
}

/// The hero of the leaderboard: one lane card per scenario with its
/// winner, the margin, and the top three. Tapping a card ranks the table by
/// that scenario. A row at desktop widths, a swipeable strip on phones.
class PodiumStrip extends StatelessWidget {
  final DashboardState state;
  final ValueChanged<String> onPick;

  const PodiumStrip({super.key, required this.state, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final scenarios = state.run!.scenarios;
    final races = [for (final s in scenarios) ScenarioRace.of(state, s)];
    return LayoutBuilder(
      builder: (context, c) {
        Widget card(int i) => _LaneCard(
          race: races[i],
          index: i,
          selected: races[i].scenario == state.sortScenario,
          onTap: () => onPick(races[i].scenario),
        );
        final perRow = races.length;
        if (c.maxWidth < 900) {
          // Swipeable strip; cards size to their content, so larger text
          // never clips.
          final w = c.maxWidth < 420 ? 280.0 : 300.0;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < races.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  SizedBox(width: w, child: card(i)),
                ],
              ],
            ),
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < perRow; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: card(i)),
              ],
            ],
          ),
        );
      },
    );
  }
}

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
    final m = race.metric;
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
                    ? kSignal.withValues(alpha: 0.7)
                    : (lit ? kBorderStrong : kBorder),
                width: _focus ? 2 : 1,
              ),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [kSignal.withValues(alpha: 0.07), kCardBgRaised],
                    )
                  : null,
            ),
            child: race.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _head(race),
                      const SizedBox(height: 16),
                      Text(
                        'No ${m.short.toLowerCase()} values here.',
                        style: body(13, color: kTextMuted),
                      ),
                    ],
                  )
                : _content(context, race),
          ),
        ),
      ),
    );
  }

  Widget _head(ScenarioRace race) => Row(
    children: [
      Expanded(
        child: Text(
          scenarioLabel(race.scenario).toUpperCase(),
          style: caps(12, color: kTextSecondary, letterSpacing: 1.6),
        ),
      ),
      if (widget.selected)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: kSignal,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'RANKING',
            style: caps(9.5, color: kSignalInk, letterSpacing: 1),
          ),
        ),
    ],
  );

  Widget _content(BuildContext context, ScenarioRace race) {
    final m = race.metric;
    final winner = race.ranked.first;
    final winnerColor = BackendColors.of(winner.key);
    final others = race.leaders - 1;
    final top = [
      for (var i = 0; i < race.ranked.length && race.positions[i] <= 3; i++) i,
    ].take(5).toList();
    final unit = unitSuffix(m);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _head(race),
        const SizedBox(height: 2),
        Text(
          scenarioHelp(race.scenario),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: body(11.5, color: kTextDim),
        ),
        const SizedBox(height: 12),
        if (others > 0)
          // A shared lead has no single winner: show who shares it.
          Row(
            children: [
              for (final b in race.ranked.take(race.leaders).take(6))
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: b.name,
                    child: Monogram(backend: b, size: 22),
                  ),
                ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${race.leaders}-way tie',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(16, color: kTextPrimary, weight: FontWeight.w700),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Monogram(backend: winner, size: 22),
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
                  style: mono(36, weight: FontWeight.w700, color: kSignal),
                ),
              ),
            ),
            if (unit.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 7),
                child: Text(unit, style: mono(11.5, color: kTextMuted)),
              ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: MarkerIcons(winner.scenarios[race.scenario]),
            ),
          ],
        ),
        Text(
          race.gapLine,
          maxLines: 2,
          style: body(
            12,
            color: race.photoFinish ? kAmber : kTextSecondary,
            weight: FontWeight.w500,
          ),
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
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(
            'P$pos',
            style: mono(
              11,
              weight: FontWeight.w700,
              color: pos == 1 ? kSignal : kTextMuted,
            ),
          ),
        ),
        SizedBox(
          width: 92,
          child: Text(
            b.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: body(11.5, color: kTextSecondary),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: LaneBar(
            fraction: race.share(index),
            color: BackendColors.of(b.key),
            height: 5,
            stagger: stagger,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 46,
          child: Text(
            formatMetricShort(race.metric, race.values[index]),
            textAlign: TextAlign.right,
            style: mono(11, color: kTextSecondary),
          ),
        ),
      ],
    );
  }
}
