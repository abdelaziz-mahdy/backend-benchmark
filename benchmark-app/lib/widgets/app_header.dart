import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/metrics.dart';
import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import 'common.dart';

String runLabel(RunIndexEntry e) {
  final date = e.date ?? 'undated';
  return switch (e.kind) {
    RunKind.latest => 'Latest results · ${e.machine.cpu}',
    RunKind.legacy => 'v1 method (Locust) · $date',
    RunKind.run => [
      date,
      if (e.contributor != null) 'by ${e.contributor}',
      e.machine.cpu,
      if (e.backends.length == 1)
        '1 backend'
      else
        '${e.backends.length} backends',
    ].join(' · '),
  };
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    return Container(
      decoration: const BoxDecoration(
        color: kCardBg,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < kNarrow;
          final pad = narrow ? 12.0 : 24.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TitleRow(narrow: narrow),
                    const SizedBox(height: 10),
                    const _Tabs(),
                    if (state.run != null) ...[
                      const Divider(height: 1, color: kBorder),
                      const _FilterBar(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final bool narrow;

  const _TitleRow({required this.narrow});

  @override
  Widget build(BuildContext context) {
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.speed, color: kBlue, size: 22),
        SizedBox(width: 8),
        Text(
          'Backend Benchmarks',
          style: TextStyle(
            color: kTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [title, const SizedBox(height: 8), const _RunPicker()],
      );
    }
    return Row(
      children: [
        title,
        const SizedBox(width: 24),
        const Spacer(),
        const Flexible(flex: 3, child: _RunPicker()),
      ],
    );
  }
}

class _RunPicker extends StatelessWidget {
  const _RunPicker();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final selected = state.entry;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected?.id,
          isExpanded: true,
          isDense: true,
          dropdownColor: kCardBg,
          icon: const Icon(Icons.expand_more, color: kTextMuted, size: 20),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(color: kTextPrimary, fontSize: 13),
          padding: const EdgeInsets.symmetric(vertical: 8),
          items: [
            for (final e in state.index)
              DropdownMenuItem(
                value: e.id,
                child: Row(
                  children: [
                    Icon(
                      switch (e.kind) {
                        RunKind.latest => Icons.auto_awesome,
                        RunKind.legacy => Icons.history,
                        RunKind.run => Icons.play_circle_outline,
                      },
                      size: 15,
                      color: e.kind == RunKind.latest ? kBlue : kTextMuted,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(runLabel(e), overflow: TextOverflow.ellipsis),
                    ),
                    if (e.dirty) ...[
                      const SizedBox(width: 6),
                      const Flag(
                        text: 'modified code',
                        tooltip:
                            'Run from a working copy with uncommitted changes.',
                      ),
                    ],
                  ],
                ),
              ),
          ],
          onChanged: (id) {
            final e = state.index.firstWhere((x) => x.id == id);
            state.selectRun(e);
          },
        ),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs();

  static const _labels = {
    DashboardTab.overview: ('Overview', Icons.leaderboard_outlined),
    DashboardTab.framework: ('Framework', Icons.insights_outlined),
    DashboardTab.compare: ('Compare', Icons.compare_arrows),
    DashboardTab.history: ('History', Icons.timeline),
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in DashboardTab.values)
            _TabButton(
              label: _labels[t]!.$1,
              icon: _labels[t]!.$2,
              selected: state.tab == t,
              onTap: () => state.setTab(t),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? kTextPrimary : kTextMuted;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? kOrange : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scenario selector and language filter, shared by all tabs.
class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final run = state.run!;
    final showLanguages = state.tab != DashboardTab.framework;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  'Scenario',
                  style: TextStyle(color: kTextMuted, fontSize: 12),
                ),
              ),
              ...[
                for (final s in run.scenarios)
                  Tooltip(
                    message: scenarioHelp(s),
                    waitDuration: const Duration(milliseconds: 300),
                    child: ChoiceChip(
                      label: Text(scenarioLabel(s)),
                      selected: state.scenario == s,
                      onSelected: (_) => state.setScenario(s),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: state.scenario == s ? kTextPrimary : kTextMuted,
                      ),
                      selectedColor: kBlue.withValues(alpha: 0.2),
                      backgroundColor: kBackground,
                      side: BorderSide(
                        color: state.scenario == s ? kBlue : kBorder,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ],
          ),
          if (showLanguages && state.allLanguages.length > 1)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    'Languages',
                    style: TextStyle(color: kTextMuted, fontSize: 12),
                  ),
                ),
                ...[
                  for (final l in state.allLanguages)
                    FilterChip(
                      label: Text(_languageLabel(l)),
                      selected: state.languages.contains(l),
                      onSelected: (_) => state.toggleLanguage(l),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        color: state.languages.contains(l)
                            ? kTextPrimary
                            : kTextMuted,
                      ),
                      selectedColor: kGreen.withValues(alpha: 0.18),
                      backgroundColor: kBackground,
                      side: BorderSide(
                        color: state.languages.contains(l) ? kGreen : kBorder,
                      ),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (state.languages.isNotEmpty)
                    TextButton(
                      onPressed: state.clearLanguages,
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

String _languageLabel(String l) => switch (l) {
  'c_sharp' => 'C#',
  'javascript' => 'JavaScript',
  _ => l[0].toUpperCase() + l.substring(1),
};
