import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/results.dart';
import '../state/dashboard_state.dart';
import '../utils/theme_constants.dart';
import 'common.dart';

/// Short name of a run for the picker: "Latest results · Apple M2 Pro".
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

/// Second line of a run in the picker: method, date, size.
String runDetail(RunIndexEntry e) => [
  e.isLegacy ? 'not comparable with v2' : 'method ${e.methodology}',
  if (e.kind == RunKind.latest && e.date != null) 'up to ${e.date}',
  if (e.kind == RunKind.latest && e.runs.length > 1)
    'combined from ${e.runs.length} runs',
  if (e.kind != RunKind.run) '${e.backends.length} frameworks',
].join(' · ');

Color _liveColor(RunIndexEntry e) => switch (e.kind) {
  RunKind.latest => kSignal,
  RunKind.run => kAmber,
  RunKind.legacy => kTextDim,
};

/// Wordmark (home), the three pages as tabs, and the timing-board pill that
/// says which data is shown and switches it in place.
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DashboardState>();
    final entry = state.entry;
    final legacy = entry?.isLegacy ?? false;
    return Container(
      decoration: BoxDecoration(
        color: kBackground,
        border: Border(
          bottom: BorderSide(
            color: legacy ? kAmber.withValues(alpha: 0.6) : kBorder,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < kNarrow;
          final pad = narrow ? 16.0 : 28.0;
          final title = _Wordmark(onTap: state.goHome, small: narrow);
          final page = state.page;
          final tabs = [
            _NavTab(
              label: 'Leaderboard',
              icon: Icons.leaderboard_outlined,
              selected: page == DashboardPage.home,
              onTap: state.goHome,
            ),
            _NavTab(
              label: 'History',
              icon: Icons.timeline,
              selected: page == DashboardPage.history,
              onTap: () => state.setPage(DashboardPage.history),
            ),
            _NavTab(
              label: narrow ? 'Method' : "How it's measured",
              icon: Icons.science_outlined,
              selected: page == DashboardPage.method,
              tooltip: "How it's measured: method, fairness rules, markers",
              onTap: () => state.setPage(DashboardPage.method),
            ),
          ];
          final data = entry == null
              ? null
              : _DataPill(state: state, entry: entry, compact: narrow);
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                child: narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              title,
                              const SizedBox(width: 6),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: data,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              for (final t in tabs) Expanded(child: t),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: title,
                          ),
                          const SizedBox(width: 28),
                          ...tabs,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: data,
                              ),
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

class _Wordmark extends StatelessWidget {
  final VoidCallback onTap;
  final bool small;

  const _Wordmark({required this.onTap, required this.small});

  @override
  Widget build(BuildContext context) {
    final size = small ? 14.0 : 20.0;
    return Semantics(
      button: true,
      label: 'Backend Benchmarks, leaderboard',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FinishFlag(size: size - 2),
              const SizedBox(width: 8),
              Text(
                'BACKEND',
                style: display(size, letterSpacing: 0.5, height: 1),
              ),
              const SizedBox(width: 3),
              Text(
                'BENCH',
                style: mono(
                  size - 3,
                  weight: FontWeight.w700,
                  color: kSignal,
                  height: 1,
                  letterSpacing: small ? 0.3 : 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final String? tooltip;
  final VoidCallback onTap;

  const _NavTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? kTextPrimary : kTextMuted;
    final tab = Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? kSignal : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? kSignal : color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: body(
                    13,
                    color: color,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null) return tab;
    return Tooltip(
      message: tooltip!,
      waitDuration: const Duration(milliseconds: 500),
      child: tab,
    );
  }
}

/// "● Data: latest · Apple M2 Pro  v2.1 ▾": opens the run list right here.
class _DataPill extends StatelessWidget {
  final DashboardState state;
  final RunIndexEntry entry;
  final bool compact;

  const _DataPill({
    required this.state,
    required this.entry,
    required this.compact,
  });

  static const _method = '__method__';

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      height: compact ? 30 : 34,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: entry.isLegacy ? kAmber.withValues(alpha: 0.6) : kBorderStrong,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _liveColor(entry),
              shape: BoxShape.circle,
              boxShadow: entry.kind == RunKind.latest
                  ? [
                      BoxShadow(
                        color: kSignal.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Flexible(
            child: Text(
              'Data: ${dataLabel(entry)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono(compact ? 10.5 : 12, color: kTextPrimary),
            ),
          ),
          if (!compact && !entry.isLegacy) ...[
            const SizedBox(width: 8),
            Text(
              entry.methodology,
              style: mono(11, color: kTextMuted, weight: FontWeight.w700),
            ),
          ],
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 16, color: kTextMuted),
        ],
      ),
    );
    return PopupMenuButton<String>(
      tooltip: 'Which run is shown; pick another',
      color: kCardBgRaised,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 380),
      onSelected: (id) {
        if (id == _method) {
          state.setPage(DashboardPage.method);
          return;
        }
        final e = state.index.where((x) => x.id == id).firstOrNull;
        if (e != null && e != state.entry) state.selectRun(e);
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text('SHOW RESULTS FROM', style: caps(10.5)),
        ),
        for (final e in state.index)
          PopupMenuItem<String>(
            value: e.id,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: _liveColor(e),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        runLabel(e),
                        overflow: TextOverflow.ellipsis,
                        style: body(
                          13,
                          color: kTextPrimary,
                          weight: e == entry
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      Text(
                        runDetail(e),
                        overflow: TextOverflow.ellipsis,
                        style: mono(11, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
                if (e.dirty)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Flag(
                      text: 'modified',
                      tooltip:
                          'Run from a working copy with uncommitted changes.',
                    ),
                  ),
                if (e == entry)
                  const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.check, size: 16, color: kSignal),
                  ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: _method,
          child: Row(
            children: [
              const Icon(Icons.science_outlined, size: 16, color: kSignal),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'About this run and how it was measured',
                  style: body(13, color: kTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
      child: pill,
    );
  }
}
