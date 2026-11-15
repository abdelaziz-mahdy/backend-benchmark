import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/plain.dart';
import '../models/results.dart';
import '../utils/colors.dart';
import '../utils/formatters.dart';
import '../utils/theme_constants.dart';
import 'calm.dart';
import 'motion.dart';

/// The limits a load step must hold (run params "slo").
class Slo {
  final double p99Ms;
  final double errorRate;
  final double servedRatio;

  const Slo({this.p99Ms = 100, this.errorRate = 0.01, this.servedRatio = 0.95});

  factory Slo.of(Map<String, dynamic> params) {
    final m = params['slo'];
    double? n(Object? v) => v is num ? v.toDouble() : null;
    if (m is! Map) return const Slo();
    return Slo(
      p99Ms: n(m['p99_ms']) ?? 100,
      errorRate: n(m['error_rate']) ?? 0.01,
      servedRatio: n(m['achieved_ratio']) ?? 0.95,
    );
  }

  /// Why [s] failed, from its recorded numbers, in plain words: "slow
  /// reply 412 ms", "3.1% errors", "answered 88%", "our testing tool's
  /// limit"; "" when it passed.
  String reason(LoadStep s) {
    if (s.pass) return '';
    final parts = [
      if (s.p99 >= p99Ms) 'slow reply ${msText(s.p99)}',
      if (s.errorRate >= errorRate)
        '${(s.errorRate * 100).toStringAsFixed(1)}% errors',
      if (s.targetRps > 0 && s.achievedRps / s.targetRps < servedRatio)
        'answered ${(s.achievedRps / s.targetRps * 100).round()}%',
    ];
    if (s.k6Bound) return "our testing tool's limit";
    return parts.isEmpty ? 'failed a limit' : parts.join(', ');
  }
}

/// Replays the recorded load steps (the median repetition of each
/// framework) as a race: at every requested rate each lane shows what was
/// served, turns red at the step that broke a limit (amber when the load
/// generator itself was the limit), and keeps a lime flag at the highest
/// step it held. Lanes re-order by that flag as they overtake. Every number
/// is a recorded step; nothing is interpolated.
class RaceReplay extends StatefulWidget {
  final List<BackendResult> backends;
  final String scenario;
  final Slo slo;

  const RaceReplay({
    super.key,
    required this.backends,
    required this.scenario,
    required this.slo,
  });

  @override
  State<RaceReplay> createState() => _RaceReplayState();
}

class _Lane {
  final BackendResult backend;
  final List<LoadStep> steps; // by requested rate

  _Lane(this.backend, this.steps);

  /// The step at [rate], or the last one below it once this framework had
  /// stopped climbing; null before its first step.
  LoadStep? at(double rate) {
    LoadStep? last;
    for (final s in steps) {
      if (s.targetRps > rate) break;
      last = s;
    }
    return last;
  }

  /// Highest requested rate held up to [rate].
  double? heldUpTo(double rate) {
    double? best;
    for (final s in steps) {
      if (s.targetRps > rate) break;
      if (s.pass) best = s.targetRps;
    }
    return best;
  }

  double get top => steps.isEmpty ? 0 : steps.last.targetRps;
}

class _RaceReplayState extends State<RaceReplay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _play;
  late List<_Lane> _lanes;
  late List<double> _rates;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _play = AnimationController(vsync: this)..addListener(_onTick);
    _build();
    _step = _rates.isEmpty ? 0 : _rates.length - 1;
  }

  @override
  void didUpdateWidget(RaceReplay old) {
    super.didUpdateWidget(old);
    // Identity, not keys: a run switch brings new results for the same keys.
    final same =
        old.backends.length == widget.backends.length &&
        [
          for (var i = 0; i < old.backends.length; i++)
            identical(old.backends[i], widget.backends[i]),
        ].every((x) => x);
    if (old.scenario != widget.scenario || !same) {
      _play.stop();
      _build();
      _step = _rates.isEmpty ? 0 : _rates.length - 1;
    }
  }

  void _build() {
    _lanes = [
      for (final b in widget.backends)
        if (b.scenarios[widget.scenario]?.steps case final steps?
            when steps.isNotEmpty)
          _Lane(
            b,
            [...steps]..sort((a, c) => a.targetRps.compareTo(c.targetRps)),
          ),
    ];
    _rates = {
      for (final l in _lanes)
        for (final s in l.steps) s.targetRps,
    }.toList()..sort();
  }

  void _onTick() {
    final next = (_play.value * (_rates.length - 1)).floor();
    if (next != _step) setState(() => _step = next);
  }

  void _toggle() {
    if (_play.isAnimating) {
      _play.stop();
      setState(() {});
      return;
    }
    if (reducedMotion(context)) {
      setState(() => _step = _rates.length - 1);
      return;
    }
    final from = _step >= _rates.length - 1 ? 0 : _step;
    _play.duration = Duration(milliseconds: 420 * _rates.length);
    _play.forward(from: from / math.max(1, _rates.length - 1));
    setState(() => _step = from);
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lanes.isEmpty || _rates.isEmpty) {
      return Text(
        'No recorded steps for this test.',
        style: body(13, color: context.palette.muted),
      );
    }
    final rate = _rates[_step.clamp(0, _rates.length - 1)];
    final base = _rates.first;
    final top = _rates.last;
    double scale(double rps) => rps <= 0 || top <= base
        ? 0
        : (math.log(math.max(rps, base) / base) / math.log(top / base) * 0.94 +
                  0.06)
              .clamp(0.0, 1.0);
    // Best held so far first: lanes overtake as the replay climbs.
    final order = [..._lanes]
      ..sort((a, b) {
        final c = (b.heldUpTo(rate) ?? 0).compareTo(a.heldUpTo(rate) ?? 0);
        return c != 0 ? c : a.backend.name.compareTo(b.backend.name);
      });
    final playing = _play.isAnimating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton.filled(
              tooltip: playing ? 'Pause the replay' : 'Replay the race',
              onPressed: _toggle,
              style: IconButton.styleFrom(
                backgroundColor: context.palette.accent,
                foregroundColor: context.palette.accentInk,
              ),
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Asked for', style: caps(10.5)),
                Text(
                  '${whole(rate)} a second',
                  style: mono(18, weight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: context.palette.accent,
                  inactiveTrackColor: context.palette.line,
                  thumbColor: context.palette.accent,
                  overlayColor: context.palette.accent.withValues(alpha: 0.12),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _step.toDouble(),
                  min: 0,
                  max: math.max(1, _rates.length - 1).toDouble(),
                  divisions: math.max(1, _rates.length - 1),
                  label: '${whole(rate)} a second',
                  semanticFormatterCallback: (v) =>
                      '${formatRps(_rates[v.round().clamp(0, _rates.length - 1)])} '
                      'requests per second requested',
                  onChanged: (v) {
                    _play.stop();
                    setState(() => _step = v.round());
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        RepaintBoundary(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final l in order)
                FlipOnMove(
                  key: ValueKey('replay-${l.backend.key}'),
                  duration: const Duration(milliseconds: 350),
                  child: _ReplayLane(
                    lane: l,
                    rate: rate,
                    slo: widget.slo,
                    scale: scale,
                    last: _step == _rates.length - 1,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, c) => Padding(
            padding: EdgeInsets.only(left: c.maxWidth < 560 ? 0 : 150),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                _key(
                  context.palette.accent,
                  'flag: the busiest step passed so far',
                ),
                _key(
                  context.palette.danger,
                  'failed: too slow, too many errors '
                  'or could not keep up',
                  hatched: true,
                ),
                _key(
                  context.palette.warn,
                  "hit our testing tool's limit",
                  hatched: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _key(Color c, String text, {bool hatched = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 10,
        height: 10,
        child: hatched ? HatchFill(color: c) : ColoredBox(color: c),
      ),
      const SizedBox(width: 5),
      Text(text, style: body(11.5, color: context.palette.muted)),
    ],
  );
}

class _ReplayLane extends StatelessWidget {
  final _Lane lane;
  final double rate;
  final Slo slo;
  final double Function(double) scale;

  /// The final frame: every lane shows its result, so the one that went
  /// furthest is not left reading "failed".
  final bool last;

  const _ReplayLane({
    required this.lane,
    required this.rate,
    required this.slo,
    required this.scale,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final b = lane.backend;
    final step = lane.at(rate);
    final held = lane.heldUpTo(rate);
    final done = rate > lane.top || last; // stopped climbing, or the end
    final failed = step != null && !step.pass;
    final exact = step != null && step.targetRps == rate;
    final status = step == null
        ? 'not started'
        : done
        ? 'passed ${whole(held ?? 0)} · stopped at ${whole(lane.top)}'
        : failed
        ? 'failed at ${whole(step.targetRps)}: ${slo.reason(step)}'
        : exact
        ? 'answered ${whole(step.achievedRps)} a second'
        : 'passed ${whole(step.targetRps)}; no step at this rate';
    final barColor = step == null
        ? context.palette.line
        : !failed
        ? identityColor(context.palette, b.key)
        : step.k6Bound
        ? context.palette.warn
        : context.palette.danger;
    final statusColor = failed && !done
        ? (step.k6Bound ? context.palette.warn : context.palette.danger)
        : context.palette.text;
    return Semantics(
      label: '${b.name}: $status',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: LayoutBuilder(
          builder: (context, c) {
            final narrow = c.maxWidth < 560;
            final name = Row(
              children: [
                LangBadge.of(b.key, b.language, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    b.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(
                      13,
                      color: context.palette.text,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
            final track = SizedBox(
              height: 16,
              child: LayoutBuilder(
                builder: (context, t) {
                  final w = t.maxWidth;
                  final served = step == null ? 0.0 : scale(step.achievedRps);
                  final flag = held == null ? null : scale(held);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        top: 5,
                        bottom: 5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.palette.line,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        duration: motion(context, 260),
                        curve: Curves.easeOutCubic,
                        left: 0,
                        top: 3,
                        bottom: 3,
                        width: w * served,
                        // A failed step is hatched, not just red, so it
                        // never depends on telling red from orange.
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: failed
                              ? Opacity(
                                  opacity: done ? 0.55 : 1,
                                  child: HatchFill(color: barColor),
                                )
                              : ColoredBox(
                                  color: barColor.withValues(
                                    alpha: done ? 0.45 : 0.9,
                                  ),
                                ),
                        ),
                      ),
                      if (flag != null)
                        AnimatedPositioned(
                          duration: motion(context, 260),
                          curve: Curves.easeOutCubic,
                          left: (w * flag - 1.5).clamp(0, w - 3),
                          top: -2,
                          bottom: -2,
                          width: 3,
                          child: Container(color: context.palette.accent),
                        ),
                    ],
                  );
                },
              ),
            );
            final label = Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono(11.5, color: statusColor),
            );
            if (narrow) {
              // Phones: the status gets its own line so it is never cut off.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  name,
                  const SizedBox(height: 4),
                  track,
                  const SizedBox(height: 2),
                  Text(
                    status,
                    maxLines: 2,
                    style: mono(11.5, color: statusColor),
                  ),
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: 150, child: name),
                Expanded(child: track),
                const SizedBox(width: 12),
                SizedBox(width: 270, child: label),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Diagonal stripes in [color] over a faint wash of it: the "failed" fill.
class HatchFill extends StatelessWidget {
  final Color color;

  const HatchFill({super.key, required this.color});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HatchPainter(color),
    child: const SizedBox.expand(),
  );
}

class _HatchPainter extends CustomPainter {
  final Color color;

  _HatchPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = color.withValues(alpha: 0.22),
    );
    final stripe = Paint()
      ..color = color
      ..strokeWidth = 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (var x = -size.height; x < size.width; x += 5) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stripe,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}
