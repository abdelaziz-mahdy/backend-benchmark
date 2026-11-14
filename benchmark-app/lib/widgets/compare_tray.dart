import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/theme_constants.dart';
import 'common.dart';

/// Add/remove one framework from the comparison. A round toggle in table
/// rows; a labelled pill where there is room ([labelled]). The limit comes
/// from [DashboardState.canAddCompare] and is said in the tooltip.
class CompareToggle extends StatelessWidget {
  final DashboardState state;
  final BackendResult backend;
  final bool labelled;

  const CompareToggle({
    super.key,
    required this.state,
    required this.backend,
    this.labelled = false,
  });

  @override
  Widget build(BuildContext context) {
    final on = state.compareKeys.contains(backend.key);
    final enabled = state.canAddCompare(backend.key);
    final tooltip = on
        ? 'Remove ${backend.name} from the comparison'
        : enabled
        ? 'Add ${backend.name} to compare'
        : 'The comparison holds up to ${DashboardState.maxCompare}; '
              'remove one first';
    final onTap = enabled ? () => state.toggleCompare(backend.key) : null;
    if (labelled) {
      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 400),
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(on ? Icons.check : Icons.add, size: 15),
          label: Text(on ? 'In compare' : 'Compare'),
          style: OutlinedButton.styleFrom(
            foregroundColor: on ? kSignalInk : kTextPrimary,
            backgroundColor: on ? kSignal : Colors.transparent,
            side: BorderSide(color: on ? kSignal : kBorderStrong),
            visualDensity: VisualDensity.compact,
            textStyle: labelStyle(context, 12.5, weight: FontWeight.w600),
          ),
        ),
      );
    }
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        toggled: on,
        enabled: enabled,
        label: on
            ? 'Remove ${backend.name} from compare'
            : 'Add ${backend.name} to compare',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: motion(context, 180),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? kSignal : Colors.transparent,
                border: Border.all(
                  color: on ? kSignal : (enabled ? kBorderStrong : kBorder),
                ),
              ),
              child: Icon(
                on ? Icons.check : Icons.add,
                size: 17,
                color: on ? kSignalInk : (enabled ? kTextSecondary : kTextDim),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pit-lane dock: the frameworks picked for comparison, at the bottom
/// of every page while any are picked. Hidden on the Compare page itself.
/// Wide: removable chips inline. Phone: one 56 px row of monograms that
/// opens a sheet with the same chips.
class CompareTray extends StatelessWidget {
  const CompareTray({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run;
    if (run == null ||
        state.compareKeys.isEmpty ||
        state.page == DashboardPage.compare) {
      return const SizedBox.shrink();
    }
    final picked = [for (final k in state.compareKeys) ?run.backend(k)];
    final ready = picked.length >= 2;
    final compare = FilledButton.icon(
      onPressed: ready ? state.openCompare : null,
      icon: const Icon(Icons.compare_arrows, size: 16),
      label: Text(ready ? 'Compare ${picked.length}' : 'Compare'),
      style: FilledButton.styleFrom(
        backgroundColor: kSignal,
        foregroundColor: kSignalInk,
        disabledBackgroundColor: kCardBg,
        disabledForegroundColor: kTextDim,
        visualDensity: VisualDensity.compact,
        textStyle: labelStyle(context, 13, weight: FontWeight.w700),
      ),
    );
    final clear = TextButton(
      onPressed: state.clearCompare,
      style: TextButton.styleFrom(foregroundColor: kTextMuted),
      child: const Text('Clear', style: TextStyle(fontSize: 12.5)),
    );
    final status = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ready ? 'Comparing' : 'Add one more to compare',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: body(12.5, color: kTextPrimary, weight: FontWeight.w600),
        ),
        Text(
          '${picked.length} of ${DashboardState.maxCompare}',
          style: mono(11, color: kTextMuted),
        ),
      ],
    );
    return Container(
      decoration: const BoxDecoration(
        color: kCardBgRaised,
        border: Border(top: BorderSide(color: kBorderStrong)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: LayoutBuilder(
              builder: (context, c) {
                if (c.maxWidth < kNarrow) {
                  return SizedBox(
                    height: 56,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          _AvatarStack(
                            picked: picked,
                            onTap: () => _openSheet(context),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: status),
                          clear,
                          const SizedBox(width: 4),
                          compare,
                        ],
                      ),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(28, 10, 28, 10),
                  child: Row(
                    children: [
                      status,
                      const SizedBox(width: 16),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final b in picked)
                              DockChip(
                                key: ValueKey(b.key),
                                backend: b,
                                onRemove: () => state.toggleCompare(b.key),
                              ),
                          ],
                        ),
                      ),
                      clear,
                      const SizedBox(width: 8),
                      compare,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kCardBgRaised,
      showDragHandle: true,
      builder: (sheet) {
        final state = sheet.watch<DashboardState>();
        final run = state.run;
        final picked = [for (final k in state.compareKeys) ?run?.backend(k)];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('IN THE COMPARISON', style: caps(11)),
                const SizedBox(height: 10),
                if (picked.isEmpty)
                  Text('Nothing picked.', style: body(13, color: kTextMuted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final b in picked)
                        DockChip(
                          key: ValueKey(b.key),
                          backend: b,
                          onRemove: () => state.toggleCompare(b.key),
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        state.clearCompare();
                        Navigator.of(sheet).pop();
                      },
                      child: const Text('Clear'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: picked.length >= 2
                          ? () {
                              Navigator.of(sheet).pop();
                              state.openCompare();
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: kSignal,
                        foregroundColor: kSignalInk,
                      ),
                      child: Text('Compare ${picked.length}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One picked framework: identity edge, monogram, name and a remove button.
/// Pops in once when it is added, so it reads as the thing the row toggle
/// just sent here.
class DockChip extends StatelessWidget {
  final BackendResult backend;
  final VoidCallback onRemove;

  const DockChip({super.key, required this.backend, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final color = BackendColors.of(backend.key);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: motion(context, 260),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        height: 34,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: kBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, color: color),
            const SizedBox(width: 7),
            Monogram(backend: backend, size: 20),
            const SizedBox(width: 7),
            Text(
              backend.name,
              style: body(12.5, color: kTextPrimary, weight: FontWeight.w500),
            ),
            IconButton(
              tooltip: 'Remove ${backend.name}',
              onPressed: onRemove,
              iconSize: 15,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close, color: kTextMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<BackendResult> picked;
  final VoidCallback onTap;

  const _AvatarStack({required this.picked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const size = 30.0, step = 20.0;
    return Tooltip(
      message: 'Show or remove the picked frameworks',
      child: Semantics(
        button: true,
        label: 'Show the ${picked.length} picked frameworks',
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              width: size + step * (picked.length - 1) + 16,
              height: size,
              child: Stack(
                children: [
                  for (var i = 0; i < picked.length; i++)
                    Positioned(
                      left: i * step,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kCardBgRaised,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: kCardBgRaised, width: 2),
                        ),
                        child: Monogram(backend: picked[i], size: size - 4),
                      ),
                    ),
                  const Positioned(
                    right: 0,
                    top: 7,
                    child: Icon(Icons.expand_less, size: 16, color: kTextMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
