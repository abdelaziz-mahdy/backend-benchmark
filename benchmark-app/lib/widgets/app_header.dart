import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';

/// Short name of a run for the picker and the "Data" link.
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

/// Even shorter, for the header: "latest · Apple M2 Pro", "v1 · 2026-02-16".
String dataLabel(RunIndexEntry e) => switch (e.kind) {
  RunKind.latest => 'latest · ${e.machine.cpu}',
  RunKind.legacy => 'v1 method · ${e.date ?? 'undated'}',
  RunKind.run => '${e.date ?? 'undated'} · ${e.machine.cpu}',
};

/// Title plus three quiet links: which data is shown (opens the Method
/// page, where the run can be changed), History, and How it's measured.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final entry = state.entry;
    return Container(
      decoration: const BoxDecoration(
        color: kCardBg,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < kNarrow;
          final pad = narrow ? 12.0 : 24.0;
          final title = InkWell(
            onTap: state.goHome,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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
              ),
            ),
          );
          final links = Wrap(
            spacing: 2,
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (entry != null)
                _Link(
                  icon: Icons.storage_outlined,
                  label: 'Data: ${dataLabel(entry)}',
                  tooltip: 'Which run is shown; change it on the Method page',
                  flagged: entry.dirty || entry.isLegacy,
                  selected: false,
                  onTap: () => state.setPage(DashboardPage.method),
                ),
              _Link(
                icon: Icons.timeline,
                label: 'History',
                tooltip: 'How results changed across runs',
                selected: state.page == DashboardPage.history,
                onTap: () => state.setPage(DashboardPage.history),
              ),
              _Link(
                icon: Icons.science_outlined,
                label: "How it's measured",
                tooltip: 'Method, fairness rules, flags and glossary',
                selected: state.page == DashboardPage.method,
                onTap: () => state.setPage(DashboardPage.method),
              ),
            ],
          );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 6),
                child: narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, links],
                      )
                    : Row(
                        children: [
                          title,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: links,
                            ),
                          ),
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

class _Link extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final bool flagged;
  final VoidCallback onTap;

  const _Link({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.flagged = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? kTextPrimary : kTextMuted;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: flagged ? kYellow : color),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          textStyle: labelStyle(
            context,
            12.5,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
