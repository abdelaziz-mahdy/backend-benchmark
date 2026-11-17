import 'package:material_ui/material_ui.dart';

import '../../models/plain.dart';
import '../../models/results.dart';
import '../../utils/colors.dart';
import '../../utils/theme_constants.dart';
import '../../widgets/calm.dart';

/// What the overall score is, for the (i) by its title.
const overallMeaning =
    'One score from all four tests. In each test, a framework\'s result is '
    'divided by the best result in that test. The four shares are combined '
    'with a geometric mean, so one weak test pulls the score down. 100 means '
    'the best in every test. Higher is better.';

/// Whether [run] has an overall score for any framework.
bool hasOverallScores(RunSummary run) =>
    run.backends.any((b) => b.overall?.score != null);

/// "Overall score (all four tests)" with its (i), then one bar per
/// framework, highest first. A row opens the framework's page. Frameworks
/// missing a test come last with "—", which names the missing test.
class OverallScoreBars extends StatelessWidget {
  final RunSummary run;
  final String? mine;
  final void Function(String key) onOpen;

  const OverallScoreBars({
    super.key,
    required this.run,
    required this.mine,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final scored =
        [
          for (final b in run.backends)
            if (b.overall?.score != null) b,
        ]..sort((a, b) {
          final c = b.overall!.score!.compareTo(a.overall!.score!);
          return c != 0 ? c : a.name.compareTo(b.name);
        });
    final unscored = [
      for (final b in run.backends)
        if (b.overall != null && b.overall!.score == null) b,
    ];
    final max = scored.isEmpty ? 100.0 : scored.first.overall!.score!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Row(
            children: [
              Icon(Icons.leaderboard_outlined, size: 22, color: p.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Overall score (all four tests)', style: t.h2),
              ),
              const InfoTip(overallMeaning),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            final double? nameWidth = c.maxWidth >= 600 ? 200.0 : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final b in [...scored, ...unscored])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: _row(b, max, nameWidth, t, p),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _row(
    BackendResult b,
    double max,
    double? nameWidth,
    Txt t,
    Palette p,
  ) {
    final o = b.overall!;
    final score = o.score;
    final color = BackendColors.of(b.key);
    final share = score == null || max <= 0
        ? 0.0
        : (score / max).clamp(0.0, 1.0);
    final numberStyle = t.body.copyWith(
      fontSize: 15.5,
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final text = score == null ? '—' : '${whole(score)}${o.capped ? '+' : ''}';
    final tip = score == null
        ? 'Not scored: no result for '
              '${o.missing.map((id) => testInfo(id).title).join(', ')}.'
        : o.capped
        ? "+ = in at least one test it hit our testing tool's limit, so it may "
              'score higher.'
        : null;
    final numberText = Text(
      text,
      textAlign: TextAlign.right,
      style: numberStyle,
    );
    final number = SizedBox(
      width: 76,
      child: tip == null
          ? numberText
          : Tooltip(
              message: tip,
              triggerMode: TooltipTriggerMode.longPress,
              child: numberText,
            ),
    );
    return Pressable(
      key: ValueKey('score-${b.key}'),
      onTap: () => onOpen(b.key),
      radius: 10,
      semanticLabel:
          '${b.name}, overall score ${score == null ? 'not scored' : text}. '
          'Open its page.',
      builder: (context, hovered) => Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: hovered ? p.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: b.key == mine ? p.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Builder(
          builder: (context) {
            final label = Row(
              children: [
                LangBadge(color: color, tag: monogramOf(b.language)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.body.copyWith(fontSize: 15.5, height: 1.2),
                  ),
                ),
              ],
            );
            final bar = SpeedBar(share: share, color: color, capped: o.capped);
            // Says the row leads to the framework's page.
            final more = Icon(
              Icons.chevron_right,
              size: 20,
              color: hovered ? p.accent : p.muted,
            );
            if (nameWidth == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: label),
                      number,
                      const SizedBox(width: 4),
                      more,
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: bar,
                  ),
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: nameWidth, child: label),
                const SizedBox(width: 12),
                Expanded(child: bar),
                const SizedBox(width: 10),
                number,
                const SizedBox(width: 4),
                more,
              ],
            );
          },
        ),
      ),
    );
  }
}
