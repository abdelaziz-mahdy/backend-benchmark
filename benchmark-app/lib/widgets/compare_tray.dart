import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/dashboard_state.dart';
import '../utils/colors.dart';
import '../utils/theme_constants.dart';
import 'common.dart';

/// Persistent bar at the bottom while frameworks are picked for comparison.
/// Survives page, scenario and run switches; hidden when empty or while the
/// Compare page itself is open.
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
    return Container(
      decoration: const BoxDecoration(
        color: kCardBgRaised,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  ready ? 'Comparing' : 'Add one more to compare',
                  style: const TextStyle(color: kTextMuted, fontSize: 12.5),
                ),
                for (final b in picked)
                  InputChip(
                    avatar: ColorDot(color: BackendColors.of(b.key), size: 9),
                    label: Text(b.name),
                    labelStyle: const TextStyle(
                      color: kTextPrimary,
                      fontSize: 12.5,
                    ),
                    backgroundColor: kBackground,
                    side: const BorderSide(color: kBorder),
                    deleteIconColor: kTextMuted,
                    deleteButtonTooltipMessage: 'Remove ${b.name}',
                    visualDensity: VisualDensity.compact,
                    onDeleted: () => state.toggleCompare(b.key),
                  ),
                FilledButton.icon(
                  onPressed: ready ? state.openCompare : null,
                  icon: const Icon(Icons.compare_arrows, size: 16),
                  label: Text(ready ? 'Compare ${picked.length}' : 'Compare'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kBlue,
                    foregroundColor: kBackground,
                    visualDensity: VisualDensity.compact,
                    textStyle: labelStyle(
                      context,
                      12.5,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: state.clearCompare,
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
