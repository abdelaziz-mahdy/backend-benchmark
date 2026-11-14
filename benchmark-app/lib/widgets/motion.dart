import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

import '../utils/theme_constants.dart';

/// Slides its child from where it was painted last frame to where it is
/// painted now ("overtaking" when the ranking is re-sorted). Positions are
/// compared within the nearest repaint boundary, so put one around the list
/// whose rows move. Does nothing with reduced motion.
class FlipOnMove extends SingleChildRenderObjectWidget {
  final bool enabled;
  final Duration duration;

  const FlipOnMove({
    super.key,
    this.enabled = true,
    this.duration = const Duration(milliseconds: 450),
    required Widget super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderFlip(enabled && !reducedMotion(context), duration);

  @override
  void updateRenderObject(BuildContext context, RenderFlip renderObject) {
    renderObject
      ..enabled = enabled && !reducedMotion(context)
      ..duration = duration;
  }
}

class RenderFlip extends RenderProxyBox {
  bool enabled;
  Duration duration;

  RenderFlip(this.enabled, this.duration);

  Offset? _last;
  Offset _from = Offset.zero;
  double _t = 1;
  Ticker? _ticker;

  Offset get _shift =>
      _t >= 1 ? Offset.zero : _from * (1 - Curves.easeOutCubic.transform(_t));

  @override
  void paint(PaintingContext context, Offset offset) {
    final last = _last;
    if (enabled && last != null && offset != last) {
      // Start from wherever the child is currently drawn, mid-flight too.
      final from = last + _shift - offset;
      if (from.distance > 0.5) {
        _from = from;
        _t = 0;
        final ticker = _ticker ??= Ticker(_tick);
        if (ticker.isActive) ticker.stop();
        ticker.start();
      }
    }
    _last = offset;
    final child = this.child;
    if (child != null) context.paintChild(child, offset + _shift);
  }

  void _tick(Duration elapsed) {
    final total = duration.inMicroseconds;
    _t = total <= 0 ? 1 : (elapsed.inMicroseconds / total).clamp(0.0, 1.0);
    if (_t >= 1) _ticker?.stop();
    markNeedsPaint();
  }

  @override
  void detach() {
    _ticker?.stop();
    _t = 1;
    _last = null;
    super.detach();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// A number that counts up to [value] the first time it is shown and glides
/// to new values afterwards. The final frame always shows [format(value)].
class CountUp extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle style;
  final Duration duration;

  const CountUp({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: reducedMotion(context) ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        format(v == value ? value : v),
        style: style,
        semanticsLabel: format(value),
      ),
    );
  }
}

/// Grows from zero on first build, then animates between values: the width
/// share of a bar, with an optional stagger (0..1 of the duration) so rows
/// fill one after another.
class GrowFraction extends StatelessWidget {
  final double fraction;
  final double stagger;
  final Widget Function(BuildContext context, double fraction) builder;

  const GrowFraction({
    super.key,
    required this.fraction,
    required this.builder,
    this.stagger = 0,
  });

  @override
  Widget build(BuildContext context) {
    final s = stagger.clamp(0.0, 0.6);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: fraction),
      duration: motion(context, 600 + (s * 600).round()),
      curve: Interval(s, 1, curve: Curves.easeOutCubic),
      builder: (context, v, _) => builder(context, v),
    );
  }
}
