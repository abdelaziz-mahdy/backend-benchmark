import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/plain.dart';
import '../models/results.dart';
import '../utils/theme_constants.dart';
import 'calm.dart';

/// How a test is set up, drawn: the testing tool sends requests to the
/// framework's app, which reads and saves in the database, each on its own
/// processor cores. Under it, the load steps and the three checks a step
/// must pass. Side by side on wide screens, stacked on a phone.
class SetupDiagram extends StatelessWidget {
  final RunSummary run;

  /// Only the tool, app and database: the Method page shows the steps and
  /// the pass rule its own way.
  final bool flowOnly;

  const SetupDiagram({super.key, required this.run, this.flowOnly = false});

  /// Cores in a cpuset such as "0-1" or "5,6,7".
  static int? _cores(Object? set) {
    if (set is! String || set.isEmpty) return null;
    var n = 0;
    for (final part in set.split(',')) {
      final ends = part.split('-').map(int.tryParse).toList();
      if (ends.any((e) => e == null)) return null;
      n += ends.length == 2 ? ends[1]! - ends[0]! + 1 : 1;
    }
    return n;
  }

  static String? _memory(Object? m) => m is String
      ? m.replaceAllMapped(
          RegExp(r'^(\d+)\s*([gm])b?$', caseSensitive: false),
          (x) => '${x[1]} ${x[2]!.toUpperCase()}B',
        )
      : null;

  @override
  Widget build(BuildContext context) {
    final p = run.params;
    final sets = p['cpusets'] as Map? ?? const {};
    final mem = p['memory'] as Map? ?? const {};
    final tool = sets['k6_cores'] is num
        ? (sets['k6_cores'] as num).toInt()
        : _cores(sets['k6']);
    final app = _cores(sets['app']) ?? appCoreCount(run);
    final db = _cores(sets['db']);
    String spec(int? cores, Object? m) => [
      if (cores != null) '$cores ${cores == 1 ? 'core' : 'cores'}',
      ?_memory(m),
    ].join(' · ');
    final boxes = [
      _Box(Icons.speed, 'Testing tool', spec(tool, null)),
      _Box(Icons.dns_outlined, "The framework's app", spec(app, mem['app'])),
      _Box(Icons.storage_outlined, 'PostgreSQL database', spec(db, mem['db'])),
    ];
    const arrows = ['requests at a set rate', 'reads and saves'];
    final steps = [
      for (final s in (p['steps'] as List? ?? const []))
        if (s is num) s.toDouble(),
    ];
    final seconds = p['step_seconds'] is num
        ? whole(p['step_seconds'] as num)
        : null;
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 640;
        final flow = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (var i = 0; i < boxes.length; i++) ...[
                    Expanded(child: boxes[i]),
                    if (i < arrows.length) _Arrow(arrows[i], down: false),
                  ],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < boxes.length; i++) ...[
                    boxes[i],
                    if (i < arrows.length) _Arrow(arrows[i], down: true),
                  ],
                ],
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            flow,
            if (!flowOnly) ...[
              if (steps.length > 1) ...[
                const SizedBox(height: 18),
                _Steps(steps: steps, seconds: seconds),
              ],
              const SizedBox(height: 16),
              _Checks(run: run),
            ],
          ],
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _Box(this.icon, this.title, this.detail);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: p.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: p.accent, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.body.copyWith(fontWeight: FontWeight.w700),
                ),
                if (detail.isNotEmpty) Text(detail, style: t.small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final String label;
  final bool down;

  const _Arrow(this.label, {required this.down});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: t.small.copyWith(fontSize: 12.5),
    );
    if (down) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_downward, size: 20, color: p.accent),
            const SizedBox(width: 6),
            text,
          ],
        ),
      );
    }
    return SizedBox(
      width: 96,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          text,
          Icon(Icons.arrow_forward, size: 22, color: p.accent),
        ],
      ),
    );
  }
}

/// The load steps as a staircase: each bar one rate, held for [seconds],
/// the next one double.
class _Steps extends StatelessWidget {
  final List<double> steps;
  final String? seconds;

  const _Steps({required this.steps, required this.seconds});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    // Each step doubles the last, so heights follow the doublings: an even
    // staircase rather than a few tall bars.
    final lo = math.log(steps.reduce(math.min));
    final hi = math.log(steps.reduce(math.max));
    double height(double s) =>
        hi <= lo ? 1 : 0.15 + 0.85 * (math.log(s) - lo) / (hi - lo);
    return Semantics(
      label:
          'Load steps from ${whole(steps.first)} to ${whole(steps.last)} '
          'requests a second${seconds == null ? '' : ', $seconds seconds each'}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The rate steps up${seconds == null ? '' : ' every $seconds seconds'} '
              'until the app stops keeping up',
              style: t.small.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final s in steps) ...[
                    Expanded(
                      child: FractionallySizedBox(
                        heightFactor: height(s).clamp(0, 1),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: p.accent.withValues(alpha: 0.55),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${whole(steps.first)} a second', style: t.small),
                const Spacer(),
                Text('${whole(steps.last)} a second', style: t.small),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The three checks a step must pass, as icons.
class _Checks extends StatelessWidget {
  final RunSummary run;

  const _Checks({required this.run});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Txt(p);
    final checks = [
      (Icons.timer_outlined, '99 of 100 replies ${sloPhrase(run)}'),
      (Icons.error_outline, capFirst(errorPhrase(run))),
      (Icons.trending_up, 'Kept up with ${keptUp(run)} of requests'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'A step passes when all three hold. The result is the busiest step '
          'that passed.',
          style: t.small.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (icon, text) in checks)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 17, color: p.accent),
                    const SizedBox(width: 6),
                    Text(text, style: t.small.copyWith(color: p.text)),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
